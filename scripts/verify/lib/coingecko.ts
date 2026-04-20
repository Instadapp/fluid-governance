/**
 * Minimal CoinGecko client for the pre-deploy price-fetcher.
 *
 * We intentionally only hit the public `simple/price` endpoint:
 *   GET https://api.coingecko.com/api/v3/simple/price?ids=a,b,c&vs_currencies=usd
 *
 * which returns `{ a: { usd: 1234.5 }, b: { usd: ... }, ... }` and is cheap
 * enough to batch every token of a payload into one call. Reviewers then
 * confirm rounded values in the PR diff before the proposal is queued, so
 * the fetcher never needs to be trust-minimised.
 *
 * If `COINGECKO_API_KEY` is set (free demo key or paid pro key), we use the
 * pro host and attach the header — mostly useful to escape the aggressive
 * anonymous rate limit if a developer runs the script repeatedly.
 */

import axios, { AxiosError } from "axios";

const PUBLIC_HOST = "https://api.coingecko.com/api/v3";
const PRO_HOST = "https://pro-api.coingecko.com/api/v3";

export interface CoinGeckoClientOptions {
  /** API key (pro or demo). Optional. Read from `COINGECKO_API_KEY` if unset. */
  apiKey?: string;
  /** Max retry attempts on 429 / 5xx. Default 5. */
  maxRetries?: number;
  /** Initial backoff in ms. Default 1000 (doubled each retry). */
  initialBackoffMs?: number;
  /** Hard ceiling for a single HTTP call. Default 15_000. */
  timeoutMs?: number;
}

export class CoinGeckoClient {
  private readonly apiKey?: string;
  private readonly maxRetries: number;
  private readonly initialBackoffMs: number;
  private readonly timeoutMs: number;

  constructor(opts: CoinGeckoClientOptions = {}) {
    this.apiKey = opts.apiKey ?? process.env.COINGECKO_API_KEY;
    this.maxRetries = opts.maxRetries ?? 5;
    this.initialBackoffMs = opts.initialBackoffMs ?? 1000;
    this.timeoutMs = opts.timeoutMs ?? 15_000;
  }

  /**
   * Fetch USD prices for every `id` in one request.
   *
   * Returns a `Map<id, usdPrice>`. Unknown ids are silently omitted by the
   * API; the caller is responsible for detecting and reporting misses.
   */
  async fetchUsdPrices(ids: readonly string[]): Promise<Map<string, number>> {
    const unique = Array.from(new Set(ids));
    if (unique.length === 0) return new Map();

    const host = this.apiKey ? PRO_HOST : PUBLIC_HOST;
    const headers: Record<string, string> = { accept: "application/json" };
    if (this.apiKey) {
      // Both demo and pro keys use this header.
      headers["x-cg-pro-api-key"] = this.apiKey;
    }

    const params = {
      ids: unique.join(","),
      vs_currencies: "usd",
    };

    let attempt = 0;
    while (true) {
      attempt += 1;
      try {
        const res = await axios.get<Record<string, { usd?: number }>>(
          `${host}/simple/price`,
          { params, headers, timeout: this.timeoutMs }
        );

        const out = new Map<string, number>();
        for (const [id, payload] of Object.entries(res.data ?? {})) {
          if (payload && typeof payload.usd === "number") {
            out.set(id, payload.usd);
          }
        }
        return out;
      } catch (err) {
        const axiosErr = err as AxiosError;
        const status = axiosErr.response?.status ?? 0;
        const isRetriable = status === 429 || (status >= 500 && status < 600);

        if (!isRetriable || attempt > this.maxRetries) {
          throw wrap(axiosErr, attempt);
        }

        const backoff = this.initialBackoffMs * 2 ** (attempt - 1);
        const jitter = Math.floor(Math.random() * 250);
        await sleep(backoff + jitter);
      }
    }
  }
}

function wrap(err: AxiosError, attempt: number): Error {
  const status = err.response?.status;
  const body =
    typeof err.response?.data === "string"
      ? err.response.data.slice(0, 400)
      : JSON.stringify(err.response?.data ?? {}).slice(0, 400);
  return new Error(
    `CoinGecko request failed after ${attempt} attempt(s): ` +
      `status=${status ?? "n/a"} message=${err.message} body=${body}`
  );
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
