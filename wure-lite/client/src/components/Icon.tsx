import React from "react";

type IconName = "home" | "stats" | "users" | "settings" | "logout" | "caret-down" | "caret-up" | "trash" | "eraser";

interface IconProps {
  name: IconName;
  size?: number;
  className?: string;
  ariaHidden?: boolean;
}

export default function Icon({ name, size = 18, className, ariaHidden = true }: IconProps) {
  if (name === "home") {
    return (
      <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden={ariaHidden}>
        <path d="M3 11.5L12 3l9 8.5V21a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1v-9.5z" fill="currentColor" />
      </svg>
    );
  }
  if (name === "stats") {
    return (
      <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden={ariaHidden}>
        <rect x="3" y="4" width="18" height="4" rx="1" fill="currentColor" />
        <rect x="3" y="10" width="18" height="10" rx="1" fill="currentColor" />
      </svg>
    );
  }
  if (name === "users") {
    return (
      <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden={ariaHidden}>
        <path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm0 2c-4 0-7 2-7 4v2h14v-2c0-2-3-4-7-4z" fill="currentColor" />
      </svg>
    );
  }
  if (name === "settings") {
    return (
      <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden={ariaHidden}>
        <path d="M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z" fill="currentColor" />
        <circle cx="12" cy="12" r="1.5" fill="currentColor" />
      </svg>
    );
  }
  if (name === "logout") {
    return (
      <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden={ariaHidden}>
        <path d="M16 13v-2H7V8l-5 4 5 4v-3z" fill="currentColor" />
        <path d="M20 3h-8v2h8v14h-8v2h8a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2z" fill="currentColor" />
      </svg>
    );
  }
  if (name === "caret-down") {
    return (
      <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden={ariaHidden}>
        <path d="M6 9l6 6 6-6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }
  if (name === "trash") {
    return (
      <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden={ariaHidden}>
        <path d="M9 3.75h6a1 1 0 0 1 1 1V6h3a.75.75 0 0 1 0 1.5h-1.05l-.72 10.14A2.25 2.25 0 0 1 14.98 19.5H9.02a2.25 2.25 0 0 1-2.25-1.86L6.05 7.5H5a.75.75 0 0 1 0-1.5h3V4.75a1 1 0 0 1 1-1Zm5.5 2.25v-.75h-5V6h5Zm-6.95 1.5.7 9.93a.75.75 0 0 0 .75.57h5.96a.75.75 0 0 0 .75-.57l.7-9.93H7.55Zm2.2 2.25c.41 0 .75.34.75.75v4.5a.75.75 0 0 1-1.5 0v-4.5c0-.41.34-.75.75-.75Zm4.5 0c.41 0 .75.34.75.75v4.5a.75.75 0 0 1-1.5 0v-4.5c0-.41.34-.75.75-.75Z" fill="currentColor" />
      </svg>
    );
  }
  if (name === "eraser") {
    return (
      <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden={ariaHidden}>
        <path d="M13.98 3.72a2.25 2.25 0 0 1 3.18 0l3.12 3.12a2.25 2.25 0 0 1 0 3.18l-8.31 8.31a2.25 2.25 0 0 1-1.59.66H5.96a2.25 2.25 0 0 1-1.59-.66L2.91 16.9a2.25 2.25 0 0 1 0-3.18l11.07-11Zm1.59 1.59a.75.75 0 0 0-1.06 0L8.6 11.22l4.18 4.18 5.9-5.91a.75.75 0 0 0 0-1.06l-3.11-3.12ZM7.54 12.28 3.97 15.84a.75.75 0 0 0 0 1.06l1.46 1.44a.75.75 0 0 0 .53.22h4.42a.75.75 0 0 0 .53-.22l.81-.81-4.18-4.25Z" fill="currentColor" />
        <path d="M13 19.5h7" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
      </svg>
    );
  }
  // caret-up
  return (
    <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden={ariaHidden}>
      <path d="M18 15l-6-6-6 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
