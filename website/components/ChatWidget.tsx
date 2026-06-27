"use client";

import { useEffect } from "react";

export function ChatWidget() {
  useEffect(() => {
    const timer = setTimeout(() => {
      const widgetSrc = "https://embed.tawk.to/placeholder/1";
      if (widgetSrc.includes("/placeholder/")) return;

      const s = document.createElement("script");
      s.type = "text/javascript";
      s.async = true;
      s.src = widgetSrc;
      s.charset = "UTF-8";
      s.setAttribute("crossorigin", "*");
      document.head.appendChild(s);
    }, 3000);

    return () => clearTimeout(timer);
  }, []);

  return null;
}
