import "i18next";
import type { defaultNS, resources } from "./index";

declare module "i18next" {
  // eslint-disable-next-line @typescript-eslint/consistent-type-definitions -- module augmentation merges only with an interface
  interface CustomTypeOptions {
    defaultNS: typeof defaultNS;
    resources: (typeof resources)["en"];
  }
}
