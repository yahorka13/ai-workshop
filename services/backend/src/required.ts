// An invariant the types cannot see: the value is there, or the caller fails
// with what was missing instead of carrying undefined on. It imports nothing,
// so any module can use it.

/** The value, or an error naming what was missing when it is null or undefined. */
export function required<T>(value: T | null | undefined, what: string): T {
  if (value === null || value === undefined)
    throw new Error(`${what} is missing`);
  return value;
}
