export class ProbeError extends Error {
  override name = "ProbeError";
}

export function isAdult(age: number): boolean {
  return age >= 18;
}

export function reason(): string {
  return "probe reason";
}

export function check(age: number): void {
  if (age < 0) throw new ProbeError("probe failed");
}
