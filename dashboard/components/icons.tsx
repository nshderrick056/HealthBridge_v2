// Small stroke icons matching the Figma frames. Decorative: the text next to each one carries the meaning.
const props = {
  'aria-hidden': true,
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 2,
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
  viewBox: '0 0 24 24',
} as const;

export const AlertIcon = ({ className = 'size-4' }) => (
  <svg {...props} className={className}>
    <circle cx="12" cy="12" r="9" />
    <path d="M12 8v4M12 16h.01" />
  </svg>
);

export const UserIcon = ({ className = 'size-4' }) => (
  <svg {...props} className={className}>
    <circle cx="12" cy="8" r="4" />
    <path d="M4 21a8 8 0 0 1 16 0" />
  </svg>
);

export const CalendarIcon = ({ className = 'size-4' }) => (
  <svg {...props} className={className}>
    <rect x="3" y="5" width="18" height="16" rx="2" />
    <path d="M16 3v4M8 3v4M3 11h18" />
  </svg>
);

export const ArrowUpIcon = ({ className = 'size-4' }) => (
  <svg {...props} className={className}>
    <path d="M12 19V5M5 12l7-7 7 7" />
  </svg>
);

export const SmsIcon = ({ className = 'size-3.5' }) => (
  <svg {...props} className={className}>
    <circle cx="12" cy="12" r="9" />
    <path d="m9 9 6 6M15 9l-6 6" />
  </svg>
);

export const WifiIcon = ({ className = 'size-3.5' }) => (
  <svg {...props} className={className}>
    <path d="M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0M2 9a15 15 0 0 1 20 0M12 19.5h.01" />
  </svg>
);

export const ChevronIcon = ({ className = 'size-3.5' }) => (
  <svg {...props} className={className}>
    <path d="m9 6 6 6-6 6" />
  </svg>
);
