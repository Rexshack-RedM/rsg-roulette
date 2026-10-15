import { useState, useCallback, useEffect, useRef, Fragment, MouseEvent } from 'react';
import { isDebug, useNuiEvent, fetchNui } from './hooks/useNui';

/** locale lookup, falls back to the key so missing translations are easy to spot */
const tr = (locale: Record<string, string>, key: string) => locale?.[key] ?? key;

const CHIP_VALUES = [1, 5, 10, 25, 50, 100];
const RED_NUMBERS = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36];

interface Bet {
  type: string;
  value: number | string;
  amount: number;
}

interface GameState {
  cash: number;
  selectedChip: number;
  bets: Bet[];
  phase: 'betting' | 'spinning' | 'result' | 'waiting';
  countdown: number;
  result: number | null;
  resultColor: string | null;
  lastWin: number;
  history: { num: number; color: string }[];
  hottestNumbers: { num: number; count: number; color: string }[];
  playerWon: boolean | null;
  maxBet: number;
  locale: Record<string, string>;
}

const ROULETTE_ORDER = [
  0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
  5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26
];

function getNumberColor(num: number): string {
  if (num === 0) return 'green';
  return RED_NUMBERS.includes(num) ? 'red' : 'black';
}

function RouletteWheel({ result, resultColor, isSpinning }: { result: number | null; resultColor: string | null; isSpinning: boolean }) {
  const [rotation, setRotation] = useState(0);

  useEffect(() => {
    if (isSpinning && result !== null) {
      const resultIndex = ROULETTE_ORDER.indexOf(result);
      const segmentAngle = 360 / 37;
      const targetAngle = resultIndex * segmentAngle;
      const spins = 5 + Math.random() * 3;
      const totalRotation = rotation + spins * 360 + (360 - targetAngle);
      setRotation(totalRotation);
    }
  }, [isSpinning, result]);

  const segmentAngle = 360 / 37;
  const size = 224;
  const cx = size / 2;
  const cy = size / 2;
  const outerR = size / 2 - 2;
  const innerR = 42;
  const labelR = (outerR + innerR) / 2;

  const segments = ROULETTE_ORDER.map((num, i) => {
    const startAngle = (i * segmentAngle - 90) * (Math.PI / 180);
    const endAngle = ((i + 1) * segmentAngle - 90) * (Math.PI / 180);
    const midAngle = (startAngle + endAngle) / 2;

    const x1o = cx + outerR * Math.cos(startAngle);
    const y1o = cy + outerR * Math.sin(startAngle);
    const x2o = cx + outerR * Math.cos(endAngle);
    const y2o = cy + outerR * Math.sin(endAngle);
    const x1i = cx + innerR * Math.cos(startAngle);
    const y1i = cy + innerR * Math.sin(startAngle);
    const x2i = cx + innerR * Math.cos(endAngle);
    const y2i = cy + innerR * Math.sin(endAngle);

    const path = `M ${x1i} ${y1i} L ${x1o} ${y1o} A ${outerR} ${outerR} 0 0 1 ${x2o} ${y2o} L ${x2i} ${y2i} A ${innerR} ${innerR} 0 0 0 ${x1i} ${y1i} Z`;

    const lx = cx + labelR * Math.cos(midAngle);
    const ly = cy + labelR * Math.sin(midAngle);
    const textAngle = (midAngle * 180) / Math.PI + 90;

    const color = getNumberColor(num);
    const fill = color === 'red' ? 'var(--rl-red)' : color === 'green' ? 'var(--rl-green)' : 'var(--rl-black)';
    const isResult = result === num && !isSpinning;

    return (
      <g key={i}>
        <path d={path} fill={fill} stroke="#5a5a5a" strokeWidth={0.5} />
        {isResult && (
          <path d={path} fill="none" stroke="#ffffff" strokeWidth={2} opacity={0.7}>
            <animate attributeName="opacity" values="0.4;0.9;0.4" dur="1.2s" repeatCount="indefinite" />
          </path>
        )}
        <text
          x={lx}
          y={ly}
          textAnchor="middle"
          dominantBaseline="central"
          fill="#ffffff"
          fontSize={num === 0 ? 8 : 7}
          fontWeight="bold"
          transform={`rotate(${textAngle}, ${lx}, ${ly})`}
        >
          {num}
        </text>
      </g>
    );
  });

  return (
    <div className="relative w-56 h-56">
      <svg
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
        className="rounded-full border-2 border-[#5a5a5a] shadow-[0_10px_30px_rgba(0,0,0,0.85)]"
        style={{
          transform: `rotate(${rotation}deg)`,
          transitionDuration: isSpinning ? '4s' : '0s',
          transitionProperty: 'transform',
          transitionTimingFunction: 'cubic-bezier(0.17, 0.67, 0.12, 0.99)',
        }}
      >
        {segments}
        <circle cx={cx} cy={cy} r={innerR} fill="#0a0a0a" stroke="#5a5a5a" strokeWidth={1} />
      </svg>
      <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
        {result !== null && !isSpinning ? (
          <div
            className={`num-ball ${resultColor || 'black'} !w-12 !h-12 !text-base shadow-lg`}
            style={{ fontVariantNumeric: 'tabular-nums' }}
          >
            {result}
          </div>
        ) : (
          <div className="w-10 h-10 rounded-full bg-[#0a0a0a] border border-[#5a5a5a]" />
        )}
      </div>
      <div className="absolute top-0 left-1/2 -translate-x-1/2 -translate-y-1 w-0 h-0 border-l-8 border-r-8 border-t-[12px] border-l-transparent border-r-transparent border-t-white" />
    </div>
  );
}

function BettingBoard({ 
  bets, 
  onPlaceBet, 
  onRemoveBet,
  disabled,
  winningNumber,
  phase,
  locale
}: { 
  bets: Bet[]; 
  onPlaceBet: (type: string, value: number | string) => void;
  onRemoveBet: (type: string, value: number | string) => void;
  disabled: boolean;
  winningNumber: number | null;
  phase: string;
  locale: Record<string, string>;
}) {
  const getBetAmount = (type: string, value: number | string) => {
    const bet = bets.find(b => b.type === type && b.value === value);
    return bet?.amount || 0;
  };

  const handleContextMenu = (e: MouseEvent, type: string, value: number | string) => {
    e.preventDefault();
    if (!disabled && getBetAmount(type, value) > 0) {
      onRemoveBet(type, value);
    }
  };

  const rows = [
    [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36],
    [2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35],
    [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34],
  ];

  const CELL_W = 44;
  const CELL_H = 52;
  const ZERO_W = 56;
  const COL2_W = 44;
  const OUTSIDE_H = 40;
  const DOZEN_H = 36;
  const PADDING = 2;

  const totalW = ZERO_W + 12 * CELL_W + COL2_W + PADDING * 4;
  const totalH = 3 * CELL_H + DOZEN_H + OUTSIDE_H + PADDING * 4;

  const getSvgColor = (num: number): string => {
    const color = getNumberColor(num);
    return color === 'red' ? 'var(--rl-red)' : color === 'green' ? 'var(--rl-green)' : 'var(--rl-black)';
  };

  const getChipColor = (amount: number): { base: string; edge: string; accent: string } => {
    if (amount >= 100) return { base: '#d9a441', edge: '#7a5a20', accent: '#ffffff' };
    if (amount >= 50) return { base: '#5a4a6e', edge: '#2e2438', accent: '#9a8ab0' };
    if (amount >= 25) return { base: '#5a7d4f', edge: '#2c3f26', accent: '#8fb083' };
    if (amount >= 10) return { base: '#3e5a72', edge: '#1e2e3c', accent: '#7f9bb2' };
    if (amount >= 5) return { base: '#8e2a24', edge: '#4a1512', accent: '#c4605a' };
    return { base: '#e6e6e6', edge: '#8a8a8a', accent: '#ffffff' };
  };

  const renderChipIndicator = (x: number, y: number, amount: number) => {
    if (amount === 0) return null;
    const colors = getChipColor(amount);
    const r = 14;
    return (
      <g>
        <circle cx={x} cy={y} r={r} fill={colors.edge} />
        <circle cx={x} cy={y} r={r - 1.5} fill={colors.base} />
        <circle cx={x} cy={y} r={r - 4} fill="none" stroke={colors.accent} strokeWidth={1} strokeDasharray="3 2" />
        <circle cx={x} cy={y} r={r - 7} fill="none" stroke={colors.accent} strokeWidth={0.5} opacity={0.5} />
        <text x={x} y={y} textAnchor="middle" dominantBaseline="central" fill={amount >= 100 || amount < 5 ? '#141414' : '#ffffff'} fontSize={9} fontWeight="bold">
          {amount}
        </text>
      </g>
    );
  };

  return (
    <svg 
      viewBox={`0 0 ${totalW} ${totalH}`} 
      className="w-full h-full max-h-[400px]"
      style={{ fontFamily: 'Roboto, sans-serif' }}
    >
      <rect x={0} y={0} width={totalW} height={totalH} fill="#0a0a0a" rx={4} />

      <g transform={`translate(${PADDING}, ${PADDING})`}>
        <g 
          onClick={() => !disabled && onPlaceBet('straight', 0)}
          onContextMenu={(e) => handleContextMenu(e, 'straight', 0)}
          style={{ cursor: disabled ? 'not-allowed' : 'pointer' }}
        >
          <rect x={0} y={0} width={ZERO_W} height={3 * CELL_H} fill={getSvgColor(0)} stroke={winningNumber === 0 && phase === 'result' ? '#ffffff' : '#5a5a5a'} strokeWidth={winningNumber === 0 && phase === 'result' ? 3 : 1} rx={2} />
          {winningNumber === 0 && phase === 'result' && (
            <rect x={0} y={0} width={ZERO_W} height={3 * CELL_H} fill="none" stroke="#ffffff" strokeWidth={2} rx={2} opacity={0.6}>
              <animate attributeName="opacity" values="0.6;1;0.6" dur="1s" repeatCount="indefinite" />
            </rect>
          )}
          <text x={ZERO_W / 2} y={(3 * CELL_H) / 2} textAnchor="middle" dominantBaseline="central" fill="#ffffff" fontSize={18} fontWeight="600">
            0
          </text>
          {renderChipIndicator(ZERO_W / 2, (3 * CELL_H) / 2, getBetAmount('straight', 0))}
        </g>

        {rows.map((row, rowIdx) => (
          <g key={rowIdx} transform={`translate(${ZERO_W + PADDING}, ${rowIdx * CELL_H})`}>
            {row.map((num, colIdx) => (
              <g 
                key={num} 
                transform={`translate(${colIdx * CELL_W}, 0)`}
                onClick={() => !disabled && onPlaceBet('straight', num)}
                onContextMenu={(e) => handleContextMenu(e, 'straight', num)}
                style={{ cursor: disabled ? 'not-allowed' : 'pointer' }}
              >
                <rect x={0} y={0} width={CELL_W} height={CELL_H} fill={getSvgColor(num)} stroke={winningNumber === num && phase === 'result' ? '#ffffff' : '#5a5a5a'} strokeWidth={winningNumber === num && phase === 'result' ? 3 : 1} />
                {winningNumber === num && phase === 'result' && (
                  <rect x={0} y={0} width={CELL_W} height={CELL_H} fill="none" stroke="#ffffff" strokeWidth={2} opacity={0.6}>
                    <animate attributeName="opacity" values="0.6;1;0.6" dur="1s" repeatCount="indefinite" />
                  </rect>
                )}
                <text x={CELL_W / 2} y={CELL_H / 2} textAnchor="middle" dominantBaseline="central" fill="#ffffff" fontSize={14} fontWeight="500">
                  {num}
                </text>
                {renderChipIndicator(CELL_W / 2, CELL_H / 2, getBetAmount('straight', num))}
              </g>
            ))}
          </g>
        ))}

        {rows.map((row, rowIdx) => {
          if (rowIdx === 0) return null;
          return (
            <g key={`splits-h-${rowIdx}`} transform={`translate(${ZERO_W + PADDING}, 0)`}>
              {row.map((num, colIdx) => {
                const upperNum = rows[rowIdx - 1][colIdx];
                const splitValue = `${upperNum}-${num}`;
                const chipX = colIdx * CELL_W + CELL_W / 2;
                const chipY = rowIdx * CELL_H;
                return (
                  <g 
                  key={splitValue}
                  style={{ cursor: disabled ? 'not-allowed' : 'pointer' }}
                  onClick={() => !disabled && onPlaceBet('split', splitValue)}
                  onContextMenu={(e) => handleContextMenu(e, 'split', splitValue)}
                >
                    <rect
                      x={chipX - 6}
                      y={chipY - 6}
                      width={12}
                      height={12}
                      fill="transparent"
                    />
                    {renderChipIndicator(chipX, chipY, getBetAmount('split', splitValue))}
                  </g>
                );
              })}
            </g>
          );
        })}

        {rows.map((row, rowIdx) => (
          <g key={`splits-v-${rowIdx}`} transform={`translate(${ZERO_W + PADDING}, ${rowIdx * CELL_H})`}>
            {row.slice(1).map((num, colIdx) => {
              const leftNum = row[colIdx];
              const splitValue = `${leftNum}-${num}`;
              const chipX = (colIdx + 1) * CELL_W;
              const chipY = CELL_H / 2;
              return (
                <g 
                  key={splitValue}
                  style={{ cursor: disabled ? 'not-allowed' : 'pointer' }}
                  onClick={() => !disabled && onPlaceBet('split', splitValue)}
                  onContextMenu={(e) => handleContextMenu(e, 'split', splitValue)}
                >
                  <rect
                    x={chipX - 6}
                    y={chipY - 6}
                    width={12}
                    height={12}
                    fill="transparent"
                  />
                  {renderChipIndicator(chipX, chipY, getBetAmount('split', splitValue))}
                </g>
              );
            })}
          </g>
        ))}

        {rows.slice(1).map((row, rowIdx) => (
          <g key={`corners-${rowIdx}`} transform={`translate(${ZERO_W + PADDING}, 0)`}>
            {row.slice(1).map((_, colIdx) => {
              const actualRowIdx = rowIdx + 1;
              const tl = rows[actualRowIdx - 1][colIdx];
              const tr = rows[actualRowIdx - 1][colIdx + 1];
              const bl = rows[actualRowIdx][colIdx];
              const br = rows[actualRowIdx][colIdx + 1];
              const cornerValue = `${tl}-${tr}-${bl}-${br}`;
              const chipX = (colIdx + 1) * CELL_W;
              const chipY = actualRowIdx * CELL_H;
              return (
                <g 
                  key={cornerValue}
                  style={{ cursor: disabled ? 'not-allowed' : 'pointer' }}
                  onClick={() => !disabled && onPlaceBet('corner', cornerValue)}
                  onContextMenu={(e) => handleContextMenu(e, 'corner', cornerValue)}
                >
                  <rect
                    x={chipX - 6}
                    y={chipY - 6}
                    width={12}
                    height={12}
                    fill="transparent"
                  />
                  {renderChipIndicator(chipX, chipY, getBetAmount('corner', cornerValue))}
                </g>
              );
            })}
          </g>
        ))}

        <g transform={`translate(${ZERO_W + 12 * CELL_W + PADDING * 2}, 0)`}>
          {[3, 2, 1].map((colNum, idx) => (
            <g 
              key={colNum}
              transform={`translate(0, ${idx * CELL_H})`}
              onClick={() => !disabled && onPlaceBet(`column${colNum}`, `col${colNum}`)}
              onContextMenu={(e) => handleContextMenu(e, `column${colNum}`, `col${colNum}`)}
              style={{ cursor: disabled ? 'not-allowed' : 'pointer' }}
            >
              <rect x={0} y={0} width={COL2_W} height={CELL_H} fill="#141414" stroke="#5a5a5a" strokeWidth={1} />
              <text x={COL2_W / 2} y={CELL_H / 2} textAnchor="middle" dominantBaseline="central" fill="#f2f2f2" fontSize={12}>
                2:1
              </text>
              {renderChipIndicator(COL2_W / 2, CELL_H / 2, getBetAmount(`column${colNum}`, `col${colNum}`))}
            </g>
          ))}
        </g>

        <g transform={`translate(${ZERO_W + PADDING}, ${3 * CELL_H + PADDING})`}>
          {['1st12', '2nd12', '3rd12'].map((dozen, idx) => (
            <g 
              key={dozen}
              transform={`translate(${idx * 4 * CELL_W}, 0)`}
              onClick={() => !disabled && onPlaceBet(`dozen${idx + 1}`, dozen)}
              onContextMenu={(e) => handleContextMenu(e, `dozen${idx + 1}`, dozen)}
              style={{ cursor: disabled ? 'not-allowed' : 'pointer' }}
            >
              <rect x={0} y={0} width={4 * CELL_W} height={DOZEN_H} fill="#141414" stroke="#5a5a5a" strokeWidth={1} />
              <text x={(4 * CELL_W) / 2} y={DOZEN_H / 2} textAnchor="middle" dominantBaseline="central" fill="#f2f2f2" fontSize={12}>
                {dozen === '1st12' ? tr(locale, 'ui_dozen_1st') : dozen === '2nd12' ? tr(locale, 'ui_dozen_2nd') : tr(locale, 'ui_dozen_3rd')}
              </text>
              {renderChipIndicator((4 * CELL_W) / 2, DOZEN_H / 2, getBetAmount(`dozen${idx + 1}`, dozen))}
            </g>
          ))}
        </g>

        <g transform={`translate(${ZERO_W + PADDING}, ${3 * CELL_H + DOZEN_H + PADDING * 2})`}>
          {[
            { type: 'low', value: '1-18', label: tr(locale, 'ui_low') },
            { type: 'even', value: 'even', label: tr(locale, 'ui_even') },
            { type: 'red', value: 'red', label: tr(locale, 'ui_red'), isRed: true },
            { type: 'black', value: 'black', label: tr(locale, 'ui_black'), isBlack: true },
            { type: 'odd', value: 'odd', label: tr(locale, 'ui_odd') },
            { type: 'high', value: '19-36', label: tr(locale, 'ui_high') },
          ].map((bet, idx) => (
            <g 
              key={bet.type}
              transform={`translate(${idx * 2 * CELL_W}, 0)`}
              onClick={() => !disabled && onPlaceBet(bet.type, bet.value)}
              onContextMenu={(e) => handleContextMenu(e, bet.type, bet.value)}
              style={{ cursor: disabled ? 'not-allowed' : 'pointer' }}
            >
              <rect 
                x={0} 
                y={0} 
                width={2 * CELL_W} 
                height={OUTSIDE_H} 
                fill={bet.isRed ? 'var(--rl-red)' : bet.isBlack ? 'var(--rl-black)' : '#1c1c1c'} 
                stroke="#5a5a5a" 
                strokeWidth={1} 
              />
              <text 
                x={(2 * CELL_W) / 2} 
                y={OUTSIDE_H / 2} 
                textAnchor="middle" 
                dominantBaseline="central" 
                fill="#f2f2f2" 
                fontSize={11}
              >
                {bet.label}
              </text>
              {renderChipIndicator((2 * CELL_W) / 2, OUTSIDE_H / 2, getBetAmount(bet.type, bet.value))}
            </g>
          ))}
        </g>
      </g>
    </svg>
  );
}

function Chip({ value, selected, onClick, disabled, size = 56 }: {
  value: number;
  selected?: boolean;
  onClick?: () => void;
  disabled?: boolean;
  size?: number;
}) {
  const getChipColors = (amount: number) => {
    if (amount >= 100) return { base: '#d9a441', edge: '#7a5a20', accent: '#ffffff', text: '#141414' };
    if (amount >= 50) return { base: '#5a4a6e', edge: '#2e2438', accent: '#9a8ab0', text: '#ffffff' };
    if (amount >= 25) return { base: '#5a7d4f', edge: '#2c3f26', accent: '#8fb083', text: '#ffffff' };
    if (amount >= 10) return { base: '#3e5a72', edge: '#1e2e3c', accent: '#7f9bb2', text: '#ffffff' };
    if (amount >= 5) return { base: '#8e2a24', edge: '#4a1512', accent: '#c4605a', text: '#ffffff' };
    return { base: '#e6e6e6', edge: '#8a8a8a', accent: '#ffffff', text: '#141414' };
  };

  const colors = getChipColors(value);
  const r = size / 2;
  const innerR = r - 4;
  const dashedR = r - 8;
  const centerR = r - 14;

  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`rounded-full transition-all disabled:opacity-50 disabled:cursor-not-allowed ${
        selected ? 'scale-110 ring-2 ring-white ring-offset-2 ring-offset-black' : 'hover:scale-105'
      }`}
      style={{ width: size, height: size }}
    >
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <defs>
          <filter id={`chip-shadow-${value}`} x="-20%" y="-20%" width="140%" height="140%">
            <feDropShadow dx={0} dy={selected ? 3 : 2} stdDeviation={2} floodOpacity={0.4} />
          </filter>
        </defs>
        <circle cx={r} cy={r} r={r - 1} fill={colors.edge} filter={`url(#chip-shadow-${value})`} />
        <circle cx={r} cy={r} r={innerR} fill={colors.base} />
        <circle
          cx={r}
          cy={r}
          r={dashedR}
          fill="none"
          stroke={colors.accent}
          strokeWidth={2}
          strokeDasharray="6 4"
        />
        <circle cx={r} cy={r} r={centerR} fill="none" stroke={colors.accent} strokeWidth={1} opacity={0.4} />
        <text
          x={r}
          y={r}
          textAnchor="middle"
          dominantBaseline="central"
          fill={colors.text}
          fontSize={size < 50 ? 11 : 14}
          fontWeight="bold"
          style={{ fontFamily: 'Roboto, sans-serif' }}
        >
          {value}
        </text>
      </svg>
    </button>
  );
}

function ChipSelector({ 
  selectedChip, 
  onSelect, 
  disabled 
}: { 
  selectedChip: number; 
  onSelect: (value: number) => void;
  disabled: boolean;
}) {
  return (
    <div className="flex gap-3 justify-center flex-wrap">
      {CHIP_VALUES.map(value => (
        <Chip
          key={value}
          value={value}
          selected={selectedChip === value}
          onClick={() => !disabled && onSelect(value)}
          disabled={disabled}
        />
      ))}
    </div>
  );
}

function PhaseIndicator({ phase, countdown, locale }: { phase: string; countdown: number; locale: Record<string, string> }) {
  const phaseConfig: Record<string, { label: string; color: string }> = {
    betting: { label: tr(locale, 'ui_phase_betting'), color: 'var(--rdr-cost-ok)' },
    spinning: { label: tr(locale, 'ui_phase_spinning'), color: 'var(--rdr-amber)' },
    result: { label: tr(locale, 'ui_phase_result'), color: 'var(--rdr-gold)' },
    waiting: { label: tr(locale, 'ui_phase_waiting'), color: 'var(--rdr-muted)' }
  };
  const config = phaseConfig[phase] || phaseConfig.waiting;

  return (
    <span className="rdr-badge" style={{ color: config.color, borderColor: config.color }}>
      {config.label}
      {countdown > 0 && <span className="text-white tabular-nums">{countdown}s</span>}
    </span>
  );
}

function RouletteApp() {
  const [visible, setVisible] = useState(isDebug);
  const [rejectionMessage, setRejectionMessage] = useState<string | null>(null);
  const [state, setState] = useState<GameState>({
    cash: 1000,
    selectedChip: 10,
    bets: [],
    phase: 'betting',
    countdown: 30,
    result: null,
    resultColor: null,
    lastWin: 0,
    history: [],
    hottestNumbers: [],
    playerWon: null,
    maxBet: 500,
    locale: {}
  });

  useNuiEvent('open', (data: { cash?: number; locale?: Record<string, string> }) => {
    setVisible(true);
    if (data?.cash !== undefined || data?.locale) {
      setState(s => ({
        ...s,
        cash: data.cash ?? s.cash,
        locale: data.locale ?? s.locale
      }));
    }
  });

  useNuiEvent('close', () => setVisible(false));

  useNuiEvent('syncState', (data: {
    phase: 'betting' | 'spinning' | 'result' | 'waiting';
    countdown: number;
    result: number | null;
    resultColor: string | null;
    history: { num: number; color: string }[];
    hottestNumbers: { num: number; count: number; color: string }[];
    cash?: number;
    bets?: Bet[];
    maxBet?: number;
  }) => {
    setState(s => {
      const phaseChanged = s.phase !== data.phase;
      const transitioningToBetting = phaseChanged && data.phase === 'betting';
      
      return {
        ...s,
        phase: data.phase,
        countdown: data.countdown,
        result: data.result,
        resultColor: data.resultColor,
        history: data.history || s.history,
        hottestNumbers: data.hottestNumbers || s.hottestNumbers,
        cash: data.cash ?? s.cash,
        bets: transitioningToBetting ? [] : (data.bets || s.bets),
        maxBet: data.maxBet ?? s.maxBet,
        playerWon: data.phase !== 'result' ? null : s.playerWon,
        lastWin: data.phase !== 'result' ? 0 : s.lastWin
      };
    });
  });

  useNuiEvent('betAccepted', (data: { bets: Bet[]; cash: number }) => {
    setState(s => ({
      ...s,
      bets: data.bets,
      cash: data.cash
    }));
  });

  // one timer at a time, so a new message isn't cleared early by an older timeout
  const toastTimer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const showToast = useCallback((message: string) => {
    setRejectionMessage(message);
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setRejectionMessage(null), 3000);
  }, []);
  useEffect(() => () => clearTimeout(toastTimer.current), []);

  useNuiEvent('betRejected', (data: { message: string }) => showToast(data.message));

  useNuiEvent('betsCleared', (data: { cash?: number; autoClear?: boolean }) => {
    setState(s => ({
      ...s,
      bets: [],
      cash: data.cash ?? s.cash,
      playerWon: data.autoClear ? null : s.playerWon,
      lastWin: data.autoClear ? 0 : s.lastWin
    }));
  });

  useNuiEvent('playerResult', (data: { won: boolean; amount: number; result: number; resultColor: string }) => {
    setState(s => ({
      ...s,
      playerWon: data.won,
      lastWin: data.amount
    }));
  });

  const handleClose = useCallback(() => {
    setVisible(false);
    fetchNui('close', {}, { success: true });
  }, []);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') handleClose();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [handleClose]);

  const handlePlaceBet = useCallback((type: string, value: number | string) => {
    if (state.phase !== 'betting') return;
    
    // placed bets are already deducted from cash, only the new chip must be covered
    if (state.cash < state.selectedChip) return showToast(tr(state.locale, 'not_enough_cash'));
    const total = state.bets.reduce((sum, b) => sum + b.amount, 0);
    if (total + state.selectedChip > state.maxBet) {
      return showToast(tr(state.locale, 'total_bet_exceeds_max').replace('%s', String(state.maxBet)));
    }
    
    fetchNui('placeBet', { 
      bet: { type, value, amount: state.selectedChip } 
    }, { 
      bets: [...state.bets, { type, value, amount: state.selectedChip }],
      cash: state.cash - state.selectedChip
    });
  }, [state.phase, state.selectedChip, state.bets, state.cash, state.maxBet, state.locale, showToast]);

  const handleRemoveBet = useCallback((type: string, value: number | string) => {
    if (state.phase !== 'betting') return;
    
    const betIndex = state.bets.findIndex(b => b.type === type && b.value === value);
    if (betIndex === -1) return;
    
    fetchNui('removeBet', { 
      bet: { type, value } 
    }, { 
      bets: state.bets.filter((_, i) => i !== betIndex),
      cash: state.cash + state.bets[betIndex].amount
    });
  }, [state.phase, state.bets, state.cash]);

  const handleClearBets = useCallback(() => {
    if (state.phase !== 'betting') return;
    fetchNui('clearBets', {}, { cash: state.cash + state.bets.reduce((s, b) => s + b.amount, 0) });
  }, [state.phase, state.cash, state.bets]);

  const isSpinning = state.phase === 'spinning';
  const canBet = state.phase === 'betting';
  const totalBet = state.bets.reduce((sum, b) => sum + b.amount, 0);

  const payouts: [string, string][] = [
    [tr(state.locale, 'ui_payout_straight'), '35:1'],
    [tr(state.locale, 'ui_payout_split'), '17:1'],
    [tr(state.locale, 'ui_payout_corner'), '8:1'],
    [tr(state.locale, 'ui_payout_red_black'), '1:1'],
    [tr(state.locale, 'ui_payout_odd_even'), '1:1'],
    [tr(state.locale, 'ui_payout_low_high'), '1:1'],
    [tr(state.locale, 'ui_payout_dozens'), '2:1'],
    [tr(state.locale, 'ui_payout_columns'), '2:1'],
  ];

  const balls = (list: { num: number; color: string; count?: number }[]) =>
    list.length === 0 ? (
      <p className="text-xs italic text-[color:var(--rdr-muted)]">{tr(state.locale, 'ui_no_spins_yet')}</p>
    ) : (
      <div className="flex flex-wrap gap-1.5">
        {list.map((e, idx) => (
          <div key={idx} className="flex items-center gap-1">
            <div className={`num-ball ${e.color}`}>{e.num}</div>
            {e.count !== undefined && <span className="text-[10px] font-bold text-[color:var(--rdr-muted)]">×{e.count}</span>}
          </div>
        ))}
      </div>
    );

  if (!visible) return null;

  return (
    <div className="fixed inset-0 flex items-center justify-center">
      <div className="rdr-toast-stack">
        {rejectionMessage && (
          <div className="rdr-toast error">
            <div className="rdr-label mb-0.5">{tr(state.locale, 'ui_title')}</div>
            <p className="text-sm text-[color:var(--rdr-text)]">{rejectionMessage}</p>
          </div>
        )}
      </div>

      <div className="rdr-panel w-[80vw] h-[80vh] flex flex-col">
        <div className="relative flex flex-col items-center px-6 pt-5 pb-3">
          <h1 className="rdr-title">{tr(state.locale, 'ui_title')}</h1>
          <div className="mt-2"><PhaseIndicator phase={state.phase} countdown={state.countdown} locale={state.locale} /></div>
          <button onClick={handleClose} className="rdr-circle-btn absolute right-5 top-5" aria-label={tr(state.locale, 'ui_close')}>✕</button>
        </div>
        <div className="rdr-divider px-6">♦</div>

        <div className="flex-1 flex gap-4 p-4 overflow-hidden">
          <div className="flex-1 flex flex-col gap-3 min-w-0">
            <div className="rdr-card">
              <div className="flex justify-between items-center mb-4">
                <div>
                  <span className="rdr-label">{tr(state.locale, 'ui_balance')}</span>
                  <p className="text-white text-xl font-bold tabular-nums">${state.cash}</p>
                </div>
                <div className="text-right">
                  <span className="rdr-label">{tr(state.locale, 'ui_total_bet')}</span>
                  <p className="text-xl font-bold tabular-nums" style={{ color: totalBet > 0 ? 'var(--rdr-amber)' : 'var(--rdr-text)' }}>${totalBet}</p>
                  {state.maxBet > 0 && (
                    <span className="text-[10px] italic text-[color:var(--rdr-muted)]">{tr(state.locale, 'ui_max_bet').replace('%s', String(state.maxBet))}</span>
                  )}
                </div>
              </div>
              <ChipSelector
                selectedChip={state.selectedChip}
                onSelect={(v) => setState(s => ({ ...s, selectedChip: v }))}
                disabled={!canBet}
              />
            </div>

            <div className="flex-1 rdr-card overflow-hidden flex items-center">
              <BettingBoard
                bets={state.bets}
                onPlaceBet={handlePlaceBet}
                onRemoveBet={handleRemoveBet}
                disabled={!canBet}
                winningNumber={state.result}
                phase={state.phase}
                locale={state.locale}
              />
            </div>

            <button onClick={handleClearBets} disabled={!canBet || state.bets.length === 0} className="wood-btn w-full">
              {tr(state.locale, 'ui_clear_bets')}
            </button>
          </div>

          <div className="w-64 flex flex-col gap-3 overflow-y-auto">
            <div className="rdr-card flex flex-col items-center justify-center">
              <RouletteWheel result={state.result} resultColor={state.resultColor} isSpinning={isSpinning} />
              {state.playerWon !== null && state.phase === 'result' && (
                <p className="mt-3 text-base font-semibold uppercase tracking-wider" style={{ color: state.playerWon ? 'var(--rdr-cost-ok)' : 'var(--rdr-cost-over)' }}>
                  {state.playerWon ? tr(state.locale, 'ui_won').replace('%s', String(state.lastWin)) : tr(state.locale, 'ui_no_win')}
                </p>
              )}
            </div>

            <div className="rdr-card">
              <h3 className="rdr-label mb-2">{tr(state.locale, 'ui_hottest_numbers')}</h3>
              {balls(state.hottestNumbers)}
            </div>

            <div className="rdr-card">
              <h3 className="rdr-label mb-2">{tr(state.locale, 'ui_last_12')}</h3>
              {balls(state.history)}
            </div>

            <div className="rdr-card">
              <h3 className="rdr-label mb-2">{tr(state.locale, 'ui_payouts')}</h3>
              <div className="text-xs grid grid-cols-2 gap-x-3 gap-y-0.5">
                {payouts.map(([label, odds]) => (
                  <Fragment key={label}>
                    <p className="italic text-[color:var(--rdr-muted)]">{label}</p>
                    <p className="text-right font-semibold text-white">{odds}</p>
                  </Fragment>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

interface PlacementState {
  visible: boolean;
  heading?: number;
  height?: number;
  status?: 'ok' | 'too_close' | 'too_far' | 'no_ground';
  locale?: Record<string, string>;
}

function PlacementHud() {
  const [hud, setHud] = useState<PlacementState>({ visible: false });
  const [locale, setLocale] = useState<Record<string, string>>({});

  useNuiEvent('placement', (data: PlacementState) => {
    if (data.locale) setLocale(data.locale);
    setHud(data);
  });

  if (!hud.visible) return null;

  const t = (key: string) => tr(locale, key);
  const ok = hud.status === 'ok';
  const statusText = ok
    ? t('ui_place_status_ok')
    : hud.status === 'too_close'
    ? t('ui_place_status_too_close')
    : hud.status === 'too_far'
    ? t('ui_place_status_too_far')
    : t('ui_place_status_no_ground');

  const keys: [string, string][] = [
    [t('ui_place_mouse'), t('ui_place_aim')],
    ['←', t('ui_place_rotate_left')],
    ['→', t('ui_place_rotate_right')],
    ['↑', t('ui_place_raise')],
    ['↓', t('ui_place_lower')],
    [t('ui_key_enter'), t('ui_place_confirm')],
    [t('ui_key_backspace'), t('ui_place_cancel')],
  ];

  return (
    <div className="rdr-panel fixed top-6 left-6 w-[300px] px-5 py-4 rdr-hud-in">
      <div className="text-center">
        <div className="text-lg font-bold uppercase tracking-[1px] text-white" style={{ textShadow: '0 2px 6px rgba(0,0,0,0.9)' }}>
          {t('ui_place_title')}
        </div>
        <div className="rdr-subtitle">{t('ui_place_subtitle')}</div>
      </div>
      <div className="rdr-divider my-3">♦</div>

      <div className="flex flex-col gap-1.5">
        {keys.map(([key, label]) => (
          <div key={key} className="flex items-center justify-between text-sm">
            <span className="italic text-[color:var(--rdr-muted)]">{label}</span>
            <span className="rdr-key">{key}</span>
          </div>
        ))}
      </div>

      <div className="rdr-divider my-3">♦</div>

      <div className="grid grid-cols-2 gap-2 mb-3">
        <div className="rdr-card !p-2 text-center">
          <div className="rdr-label">{t('ui_place_heading')}</div>
          <div className="text-white font-bold tabular-nums">{hud.heading}°</div>
        </div>
        <div className="rdr-card !p-2 text-center">
          <div className="rdr-label">{t('ui_place_height')}</div>
          <div className="text-white font-bold tabular-nums">{(hud.height ?? 0) > 0 ? '+' : ''}{hud.height?.toFixed(2)}m</div>
        </div>
      </div>

      <div
        className="rdr-status"
        style={{ borderLeftColor: ok ? 'var(--rdr-cost-ok)' : 'var(--rdr-cost-over)', color: ok ? 'var(--rdr-cost-ok)' : 'var(--rdr-cost-over)' }}
      >
        <span className="rdr-dot" style={{ background: ok ? 'var(--rdr-cost-ok)' : 'var(--rdr-cost-over)' }} />
        {statusText}
      </div>
    </div>
  );
}

export default function App() {
  return (
    <>
      <PlacementHud />
      <RouletteApp />
    </>
  );
}
