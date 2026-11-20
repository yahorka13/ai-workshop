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

export function unused(): number {
  return 41 + 1;
}

// A schema definition as Pothos takes it: settings read once, and a function
// run per request.
const builder = {
  field: (config: {
    description: string;
    resolve: (status: string) => string | null;
  }) => config,
};

export const probeField = builder.field({
  description: "probe description",
  resolve: (status) => (status === "other" ? "probe detail" : null),
});
