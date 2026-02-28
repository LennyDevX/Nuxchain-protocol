/**
 * useTreasuryHealth — React hook for TreasuryManager admin dashboard
 *
 * Fetches the complete treasury state from the on-chain TreasuryManager contract
 * and returns structured data ready for UI rendering.
 *
 * Usage (admin dashboard component):
 *   const { data, isLoading, error, refetch } = useTreasuryHealth();
 *
 * Auto-refreshes every 60 seconds. Can also be triggered manually via refetch().
 */

import { useState, useEffect, useCallback } from "react";
import { ethers } from "ethers";
import {
  TreasuryManagerABI,
  TreasuryType,
  TREASURY_TYPE_LABELS,
  ProtocolStatus,
  PROTOCOL_STATUS_LABELS,
  TREASURY_MANAGER_ADDRESS,
} from "../abis/TreasuryManager";

// ─── Types ───────────────────────────────────────────────────────────────────

export interface TreasuryAllocation {
  type: TreasuryType;
  label: string;
  allocationBps: number;       // basis points (10 000 = 100 %)
  allocationPct: number;       // human-readable percent
  address: string;
  estimatedShare: bigint;      // share of next distributable amount
}

export interface TreasuryProtocolStatus {
  type: TreasuryType;
  label: string;
  status: ProtocolStatus;
  statusLabel: string;
  deficit: bigint;
}

export interface TreasuryHealthData {
  // ── Basic balances
  contractBalance: bigint;     // raw on-chain POL balance
  availableBalance: bigint;    // contractBalance − reserveFundBalance
  reserveBalance: bigint;      // locked emergency reserve
  pendingDistribution: bigint; // available − reserve (≈ next distribution)

  // ── Historical totals
  totalRevenueReceived: bigint;
  totalDistributed: bigint;

  // ── Reserve stats
  reserveAccumulated: bigint;
  reserveWithdrawn: bigint;
  reserveAllocationPct: number;     // e.g. 20
  reserveAccumulationEnabled: boolean;

  // ── Distribution timeline
  firstDepositTime: Date | null;
  lastDistributionTime: Date | null;
  nextDistributionTime: Date | null;
  timeUntilNextSecs: number;
  distributionReady: boolean;
  cycleProgressPct: number;         // 0-100
  autoDistributionEnabled: boolean;

  // ── Allocations
  allocations: TreasuryAllocation[];

  // ── Emergency
  emergencyModeActive: boolean;
  emergencyDeclaredAt: Date | null;
  emergencyFundsUsed: bigint;

  // ── Protocol statuses (REWARDS, STAKING, COLLABORATORS, DEVELOPMENT, MARKETPLACE)
  protocolStatuses: TreasuryProtocolStatus[];

  // ── Health score 0-100
  healthScore: number;
  healthLabel: "Healthy" | "Needs Attention" | "Critical";
}

// ─── Constants ───────────────────────────────────────────────────────────────

const RPC_URL = "https://polygon-rpc.com"; // public fallback — use env var in prod
const REFRESH_INTERVAL_MS = 60_000;
const SEVEN_DAYS_SECS = 7 * 24 * 3600;

// ─── Hook ────────────────────────────────────────────────────────────────────

export function useTreasuryHealth(
  rpcUrl: string = (typeof window !== "undefined"
    ? (window as any).__ENV__?.VITE_POLYGON_RPC ?? RPC_URL
    : RPC_URL)
) {
  const [data, setData]       = useState<TreasuryHealthData | null>(null);
  const [isLoading, setLoading] = useState(true);
  const [error, setError]     = useState<string | null>(null);

  const fetch = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const provider = new ethers.JsonRpcProvider(rpcUrl);
      const tm = new ethers.Contract(TREASURY_MANAGER_ADDRESS, TreasuryManagerABI, provider);

      // ── Parallel calls ─────────────────────────────────────────────────
      const [
        stats,
        reserveStats,
        timeline,
        allocs,
        emergencyInfo,
        rawBalance,
        reserveBal,
      ] = await Promise.all([
        tm.getStats(),
        tm.getReserveStats(),
        tm.getDistributionTimeline(),
        tm.getAllAllocations(),
        tm.getEmergencyInfo(),
        provider.getBalance(TREASURY_MANAGER_ADDRESS),
        tm.reserveFundBalance(),
      ]);

      // ── Protocol statuses ──────────────────────────────────────────────
      const protocolStatuses: TreasuryProtocolStatus[] = await Promise.all(
        Object.values(TreasuryType)
          .filter((v) => typeof v === "number")
          .map(async (i) => {
            const [status, deficit] = await tm.getProtocolStatus(i as TreasuryType);
            return {
              type:        i as TreasuryType,
              label:       TREASURY_TYPE_LABELS[i as TreasuryType],
              status:      Number(status) as ProtocolStatus,
              statusLabel: PROTOCOL_STATUS_LABELS[Number(status) as ProtocolStatus] ?? "Unknown",
              deficit:     BigInt(deficit),
            };
          })
      );

      // ── Allocations ────────────────────────────────────────────────────
      const allocBps: bigint[] = [
        allocs.rewardsAlloc,
        allocs.stakingAlloc,
        allocs.collaboratorsAlloc,
        allocs.developmentAlloc,
        allocs.marketplaceAlloc,
      ];

      const available = BigInt(rawBalance) > BigInt(reserveBal)
        ? BigInt(rawBalance) - BigInt(reserveBal)
        : 0n;
      const distributable = (available * 8000n) / 10000n; // 80% after reserve cut

      const allocations: TreasuryAllocation[] = await Promise.all(
        allocBps.map(async (bps, i) => {
          const [addr] = await tm.getTreasuryConfig(i);
          return {
            type:           i as TreasuryType,
            label:          TREASURY_TYPE_LABELS[i as TreasuryType],
            allocationBps:  Number(bps),
            allocationPct:  Number(bps) / 100,
            address:        addr,
            estimatedShare: distributable > 0n ? (distributable * BigInt(bps)) / 10000n : 0n,
          };
        })
      );

      // ── Timeline helpers ───────────────────────────────────────────────
      const firstDepositTs  = Number(timeline.firstDeposit);
      const lastDistTs      = Number(timeline.lastDistribution);
      const nextDistTs      = Number(timeline.nextDistribution);
      const timeUntilNext   = Number(timeline.timeUntilNext);
      const distReady       = Boolean(timeline.isReady);

      const nowSecs = Math.floor(Date.now() / 1000);
      const elapsed = nowSecs - lastDistTs;
      const cycleProgress = lastDistTs > 0
        ? Math.min(Math.round((elapsed / SEVEN_DAYS_SECS) * 100), 100)
        : 0;

      // ── Emergency ──────────────────────────────────────────────────────
      const emergencyTs = Number(emergencyInfo.timestamp);

      // ── Health score ───────────────────────────────────────────────────
      let score = 100;
      if (BigInt(rawBalance) === 0n)           score -= 30;
      if (!stats.autoDistEnabled)              score -= 10;
      if (firstDepositTs === 0)                score -= 20;
      if (BigInt(reserveBal) === 0n)           score -= 10;
      if (emergencyInfo.isActive)              score -= 30;
      if (distReady && firstDepositTs > 0)     score -= 5;
      score = Math.max(0, score);
      const healthLabel =
        score >= 80 ? "Healthy" : score >= 50 ? "Needs Attention" : "Critical";

      // ── Assemble result ────────────────────────────────────────────────
      const result: TreasuryHealthData = {
        contractBalance:          BigInt(rawBalance),
        availableBalance:         available,
        reserveBalance:           BigInt(reserveBal),
        pendingDistribution:      available,

        totalRevenueReceived:     BigInt(stats.totalReceived),
        totalDistributed:         BigInt(stats.totalDist),

        reserveAccumulated:       BigInt(reserveStats.totalAccumulated),
        reserveWithdrawn:         BigInt(reserveStats.totalWithdrawn),
        reserveAllocationPct:     Number(reserveStats.allocationPercentage) / 100,
        reserveAccumulationEnabled: Boolean(reserveStats.isEnabled),

        firstDepositTime:         firstDepositTs > 0 ? new Date(firstDepositTs * 1000) : null,
        lastDistributionTime:     lastDistTs > 0  ? new Date(lastDistTs  * 1000) : null,
        nextDistributionTime:     nextDistTs > 0  ? new Date(nextDistTs  * 1000) : null,
        timeUntilNextSecs:        timeUntilNext,
        distributionReady:        distReady,
        cycleProgressPct:         cycleProgress,
        autoDistributionEnabled:  Boolean(stats.autoDistEnabled),

        allocations,

        emergencyModeActive:      Boolean(emergencyInfo.isActive),
        emergencyDeclaredAt:      emergencyTs > 0 ? new Date(emergencyTs * 1000) : null,
        emergencyFundsUsed:       BigInt(emergencyInfo.emergencyFundsDistributed),

        protocolStatuses,

        healthScore:  score,
        healthLabel,
      };

      setData(result);
    } catch (err: any) {
      setError(err?.message ?? "Unknown error fetching treasury data");
    } finally {
      setLoading(false);
    }
  }, [rpcUrl]);

  // Initial load + polling
  useEffect(() => {
    fetch();
    const interval = setInterval(fetch, REFRESH_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [fetch]);

  return { data, isLoading, error, refetch: fetch };
}

// ─── Helpers for UI ──────────────────────────────────────────────────────────

/** Format wei (bigint) as human POL string, e.g. "12.345678 POL" */
export function formatPOL(wei: bigint, decimals = 6): string {
  const eth = ethers.formatEther(wei);
  const num = parseFloat(eth);
  return `${num.toFixed(decimals)} POL`;
}

/** Format seconds remaining as "Xd Xh Xm" */
export function formatCountdown(secs: number): string {
  if (secs <= 0) return "Ready now";
  const d = Math.floor(secs / 86400);
  const h = Math.floor((secs % 86400) / 3600);
  const m = Math.floor((secs % 3600) / 60);
  return `${d}d ${h}h ${m}m`;
}

/** Color for health score */
export function healthColor(score: number): string {
  if (score >= 80) return "#22c55e"; // green
  if (score >= 50) return "#f59e0b"; // amber
  return "#ef4444";                   // red
}

/** Color for ProtocolStatus */
export function statusColor(status: ProtocolStatus): string {
  switch (status) {
    case ProtocolStatus.HEALTHY:   return "#22c55e";
    case ProtocolStatus.UNSTABLE:  return "#f59e0b";
    case ProtocolStatus.CRITICAL:  return "#ef4444";
    case ProtocolStatus.EMERGENCY: return "#7c3aed";
    default: return "#6b7280";
  }
}
