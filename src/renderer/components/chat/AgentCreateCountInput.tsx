import { useEffect, useState } from 'react';

export const DEFAULT_AGENT_CREATE_COUNT = 3;
export const MIN_AGENT_CREATE_COUNT = 1;
export const MAX_AGENT_CREATE_COUNT = 30;

export function clampAgentCreateCount(value: number): number {
  if (!Number.isFinite(value)) {
    return DEFAULT_AGENT_CREATE_COUNT;
  }

  return Math.min(MAX_AGENT_CREATE_COUNT, Math.max(MIN_AGENT_CREATE_COUNT, Math.floor(value)));
}

interface AgentCreateCountInputProps {
  ariaLabel: string;
  value: number;
  onChange: (value: number) => void;
}

export function AgentCreateCountInput({ ariaLabel, value, onChange }: AgentCreateCountInputProps) {
  const [draftValue, setDraftValue] = useState(String(value));

  useEffect(() => {
    setDraftValue(String(value));
  }, [value]);

  return (
    <div className="flex shrink-0 items-center gap-1">
      <span className="text-xs text-muted-foreground">x</span>
      <input
        type="number"
        min={MIN_AGENT_CREATE_COUNT}
        max={MAX_AGENT_CREATE_COUNT}
        value={draftValue}
        aria-label={ariaLabel}
        onChange={(event) => {
          const nextValue = event.currentTarget.value;
          setDraftValue(nextValue);

          const parsed = Number.parseInt(nextValue, 10);
          if (Number.isFinite(parsed)) {
            onChange(clampAgentCreateCount(parsed));
          }
        }}
        onBlur={() => {
          const clamped = clampAgentCreateCount(Number.parseInt(draftValue, 10));
          setDraftValue(String(clamped));
          onChange(clamped);
        }}
        className="h-5 w-10 rounded border border-border bg-background px-1 text-center text-xs text-foreground outline-none focus:border-ring"
      />
    </div>
  );
}
