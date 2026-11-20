import { afterAll, beforeAll, spyOn } from "bun:test";

/* happy-dom lays nothing out, so every element measures 0x0 and Recharts
   draws no chart. Call this at the top of a test file to give every element
   a 400x200 box while its tests run. */
export function withLayout(): void {
  let restore = (): void => undefined;
  beforeAll(() => {
    const box = spyOn(
      HTMLElement.prototype,
      "getBoundingClientRect",
    ).mockReturnValue(DOMRect.fromRect({ width: 400, height: 200 }));
    restore = () => {
      box.mockRestore();
    };
  });
  afterAll(() => {
    restore();
  });
}
