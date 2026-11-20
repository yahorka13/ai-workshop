// Reach a value a test expects to exist, failing with what was missing
// instead of a TypeError on undefined. Tests only: lint keeps them out of src/.

/** The value, or an error naming what was missing when it is null or undefined. */
export function defined<T>(value: T | null | undefined, what: string): T {
  if (value === null || value === undefined)
    throw new Error(`${what} is missing`);
  return value;
}

/** The list's item at index, or an error naming the list and its length. */
export function at<T>(list: readonly T[], index: number, what: string): T {
  const item = index < 0 ? undefined : list[index];
  if (item === undefined)
    throw new Error(`${what}: no item at ${index} of ${list.length}`);
  return item;
}

/** The value as an instance of type, or an error naming what was not one. */
export function instance<T>(
  value: unknown,
  type: abstract new (...args: never[]) => T,
  what: string,
): T {
  if (!(value instanceof type))
    throw new Error(`${what} is not a ${type.name}`);
  return value;
}
