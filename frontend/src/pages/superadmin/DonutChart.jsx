import React, { useId, useState } from 'react';
import './DonutChart.css';

/**
 * Part-to-whole donut.
 *
 * Deliberate constraints, per data-viz practice:
 *  - At most 6 segments; callers fold the tail into "Other" before passing data in.
 *  - Never renders for fewer than 2 segments - a one- or two-slice pie is a stat,
 *    not a chart, so the caller's `fallback` is shown instead.
 *  - The legend is always present and carries the value + share as text, so
 *    identity never depends on color alone (also the required relief for the
 *    palette slots that sit under 3:1 against the cream surface).
 */
export default function DonutChart({
  segments,
  centerLabel,
  centerValue,
  formatValue = (v) => v.toLocaleString(),
  fallback = null,
  ariaLabel,
  size = 132,
}) {
  const [hovered, setHovered] = useState(null);
  const gradientId = useId();

  const usable = (segments || []).filter((s) => s.value > 0);
  const total = usable.reduce((sum, s) => sum + s.value, 0);

  if (usable.length < 2 || total <= 0) return fallback;

  const stroke = Math.round(size * 0.15);
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const gap = 2; // surface gap between adjacent fills, in px of arc

  let offset = 0;
  const arcs = usable.map((s) => {
    const share = s.value / total;
    const length = Math.max(share * circumference - gap, 1);
    const arc = {
      ...s,
      share,
      dash: length,
      offset,
    };
    offset += share * circumference;
    return arc;
  });

  const active = hovered != null ? arcs[hovered] : null;

  return (
    <div className="dc-root">
      <div className="dc-figure">
        <svg
          width={size}
          height={size}
          viewBox={`0 0 ${size} ${size}`}
          role="img"
          aria-label={ariaLabel}
          className="dc-svg"
        >
          <g transform={`rotate(-90 ${size / 2} ${size / 2})`}>
            {/* Track keeps the ring readable when one segment is tiny. */}
            <circle
              cx={size / 2}
              cy={size / 2}
              r={radius}
              fill="none"
              strokeWidth={stroke}
              className="dc-track"
            />
            {arcs.map((a, i) => (
              <circle
                key={a.key || `${gradientId}-${i}`}
                cx={size / 2}
                cy={size / 2}
                r={radius}
                fill="none"
                stroke={a.color}
                strokeWidth={hovered === i ? stroke + 4 : stroke}
                strokeDasharray={`${a.dash} ${circumference - a.dash}`}
                strokeDashoffset={-a.offset}
                strokeLinecap="butt"
                className="dc-arc"
                onMouseEnter={() => setHovered(i)}
                onMouseLeave={() => setHovered(null)}
              />
            ))}
          </g>
        </svg>

        <div className="dc-center">
          {active ? (
            <>
              <span className="dc-center-value">{Math.round(active.share * 100)}%</span>
              <span className="dc-center-label">{active.label}</span>
            </>
          ) : (
            <>
              <span className="dc-center-value">{centerValue}</span>
              <span className="dc-center-label">{centerLabel}</span>
            </>
          )}
        </div>
      </div>

      <ul className="dc-legend">
        {arcs.map((a, i) => (
          <li
            key={a.key || `legend-${i}`}
            className={hovered === i ? 'is-active' : ''}
            onMouseEnter={() => setHovered(i)}
            onMouseLeave={() => setHovered(null)}
          >
            <span className="dc-swatch" style={{ background: a.color }} />
            <span className="dc-legend-name">{a.label}</span>
            <span className="dc-legend-value">{formatValue(a.value)}</span>
            <span className="dc-legend-share">{Math.round(a.share * 100)}%</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
