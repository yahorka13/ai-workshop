// Whether the backend can serve: it can while its database answers.
export type Health = { ok: boolean };

/** Answers whether the database can be reached. */
export type Probe = () => Promise<boolean>;

// Long enough for a busy database, short enough that a health check never hangs.
const TIMEOUT_MS = 2000;

/** The backend's health: unhealthy when the probe fails, answers false or takes longer than the timeout. */
export async function checkHealth(
  probe: Probe,
  timeoutMs = TIMEOUT_MS,
): Promise<Health> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const late = new Promise<boolean>((resolve) => {
    timer = setTimeout(() => {
      resolve(false);
    }, timeoutMs);
  });
  try {
    const ok = await Promise.race([probe().catch(() => false), late]);
    return { ok };
  } finally {
    clearTimeout(timer);
  }
}
