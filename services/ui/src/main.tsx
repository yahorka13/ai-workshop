import "@/styles/index.css";
import "@/i18n";
import { createRoot } from "react-dom/client";
import { App } from "@/app/App";

// index.html always has #root; a page without it renders nothing.
const root = document.getElementById("root");
if (root) createRoot(root).render(<App />);
