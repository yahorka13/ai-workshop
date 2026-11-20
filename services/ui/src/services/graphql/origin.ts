import { createContext } from "react";

/** The API's origin the app was built with; undefined when not configured. */
export const ApiOriginContext = createContext<string | undefined>(undefined);
