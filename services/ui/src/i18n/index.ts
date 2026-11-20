import i18next from "i18next";
import { initReactI18next } from "react-i18next";
import common from "./locales/en/common.json";

export const defaultNS = "common";
export const resources = { en: { common } } as const;

export const i18n = i18next.createInstance();
// English is the only language. The resources are inline, so init finishes
// before the first render; React escapes what it renders, so i18next does not.
void i18n.use(initReactI18next).init({
  fallbackLng: "en",
  defaultNS,
  resources,
  interpolation: { escapeValue: false },
});
