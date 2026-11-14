import { createContext, useContext, useEffect, useMemo, useReducer, type ReactNode } from 'react';
import {
  type Draft, type Person, CALENDAR_EVENT, T, followUps, initialPeople, initialsOf, sessionDrafts,
} from '../data/demo';

export type LockMode = 'private' | 'name' | 'details';
export type Appearance = 'light' | 'dark' | 'system';
export type SessionStatus = 'idle' | 'live' | 'paused' | 'ended';
export type Confidence = 'likely' | 'unsure';
export interface Toast { title: string; sub?: string; initials?: string }

export interface Account {
  name: string;
  email: string;
  method: 'apple' | 'email';
  verified: boolean;
}

export interface State {
  appearance: Appearance;
  account: Account | null;
  pairedBand: string | null;
  sample: number;                 // voice sample 1–3 during setup
  sampleDone: boolean;
  session: SessionStatus;
  sessionName: string | null;
  minutes: number;                // minutes into the session (drives the demo clock)
  lockMode: LockMode;
  match: { personId: string; confidence: Confidence } | null;
  drafts: Draft[];
  activeDraftId: string | null;
  people: Person[];
  activePersonId: string;
  tasks: string[];                // follow-up ids added to Familiar tasks
  toast: Toast | null;
  lastSessionMinutes: number | null;
}

export const baseState: State = {
  appearance: 'system',
  account: null,
  pairedBand: null,
  sample: 1,
  sampleDone: false,
  session: 'idle',
  sessionName: null,
  minutes: 0,
  lockMode: 'private',
  match: null,
  drafts: [],
  activeDraftId: null,
  people: initialPeople,
  activePersonId: 'maya',
  tasks: [],
  toast: null,
  lastSessionMinutes: null,
};

export type Action =
  | { type: 'signUp'; name: string; email: string; method: 'apple' | 'email' }
  | { type: 'verifyEmail' }
  | { type: 'signOut' }
  | { type: 'setAppearance'; appearance: Appearance }
  | { type: 'pair'; band: string }
  | { type: 'nextSample' }
  | { type: 'nameSession' }
  | { type: 'startSession' }
  | { type: 'togglePause' }
  | { type: 'endSession' }
  | { type: 'setLock'; mode: LockMode }
  | { type: 'simMatch'; personId: string; confidence: Confidence }
  | { type: 'confirmMatch' }
  | { type: 'rejectMatch' }
  | { type: 'simNewVoice' }
  | { type: 'openDraft'; id: string | null }
  | { type: 'saveDraft'; id: string; name: string; cue: string }
  | { type: 'discardDraft'; id: string }
  | { type: 'declineLatest' }
  | { type: 'addTask'; id: string }
  | { type: 'addNote'; personId: string; text: string }
  | { type: 'openPerson'; id: string }
  | { type: 'deleteConversation'; personId: string; conversationId: string }
  | { type: 'forget'; personId: string }
  | { type: 'forgetAll' }
  | { type: 'toast'; toast: Toast | null }
  | { type: 'reset'; state: State };

const TODAY = 'Today';

function touchPerson(people: Person[], id: string, sessionName: string): Person[] {
  return people.map((p) => (p.id === id ? { ...p, lastSeen: { event: sessionName, date: TODAY } } : p));
}

export function reducer(s: State, a: Action): State {
  switch (a.type) {
    case 'signUp':
      // Sign in with Apple arrives already verified; email accounts confirm a code first.
      return { ...s, account: { name: a.name.trim(), email: a.email.trim(), method: a.method, verified: a.method === 'apple' } };
    case 'signOut':
      return { ...s, account: null, toast: { title: 'Signed out', sub: 'People and notes stay on this iPhone.' } };
    case 'setAppearance':
      return { ...s, appearance: a.appearance };
    case 'verifyEmail':
      return s.account ? { ...s, account: { ...s.account, verified: true } } : s;
    case 'pair':
      return { ...s, pairedBand: a.band };
    case 'nextSample':
      return s.sample >= 3 ? { ...s, sampleDone: true } : { ...s, sample: s.sample + 1 };
    case 'nameSession':
      return { ...s, sessionName: CALENDAR_EVENT.name };
    case 'startSession': {
      // The demo skips ahead to the moment Maya is detected (26 min in).
      const name = s.sessionName ?? CALENDAR_EVENT.name;
      return {
        ...s,
        session: 'live',
        sessionName: name,
        minutes: T.mayaDetected,
        drafts: sessionDrafts,
        match: { personId: 'maya', confidence: 'likely' },
        people: touchPerson(s.people, 'maya', name),
        toast: null,
      };
    }
    case 'togglePause':
      return { ...s, session: s.session === 'paused' ? 'live' : 'paused' };
    case 'endSession': {
      const mins = Math.max(s.minutes, T.sessionEnd);
      const maya = s.people.find((p) => p.id === 'maya');
      const people = maya
        ? s.people.map((p) =>
            p.id === 'maya' && !p.conversations.some((c) => c.id === 'c-maya-bn')
              ? {
                  ...p,
                  notes: p.leftOff ? [p.leftOff, ...p.notes] : p.notes,
                  leftOff: { when: `${TODAY} · ${s.sessionName ?? 'Session'}`, text: 'Asked again for your portfolio.' },
                  conversations: [{ id: 'c-maya-bn', event: s.sessionName ?? 'Session', when: TODAY, mins: 14 }, ...p.conversations],
                }
              : p,
          )
        : s.people;
      return { ...s, session: 'ended', minutes: mins, lastSessionMinutes: mins, match: null, people, toast: null };
    }
    case 'setLock':
      return { ...s, lockMode: a.mode };
    case 'simMatch': {
      const live = s.session === 'idle' || s.session === 'ended'
        ? { session: 'live' as const, sessionName: s.sessionName ?? CALENDAR_EVENT.name, minutes: T.mayaDetected }
        : {};
      const next = { ...s, ...live, match: { personId: a.personId, confidence: a.confidence } };
      // Only a confident match counts as "seen today"; unsure ones change nothing until confirmed.
      return a.confidence === 'likely' ? { ...next, people: touchPerson(next.people, a.personId, next.sessionName ?? 'Session') } : next;
    }
    case 'confirmMatch':
      if (!s.match) return s;
      return {
        ...s,
        match: { ...s.match, confidence: 'likely' },
        people: touchPerson(s.people, s.match.personId, s.sessionName ?? 'Session'),
      };
    case 'rejectMatch':
      return {
        ...s,
        match: null,
        toast: { title: 'Got it — not a match', sub: 'Nothing was added to their profile.' },
      };
    case 'simNewVoice': {
      const n = s.drafts.length + 1;
      const d: Draft = { id: `d-sim-${Date.now()}`, heardMin: s.minutes, name: '', cue: '' };
      return { ...s, drafts: [...s.drafts, d], toast: { title: `New voice heard`, sub: `${n} not saved · expires in 7 days` } };
    }
    case 'openDraft':
      return { ...s, activeDraftId: a.id };
    case 'saveDraft': {
      const name = a.name.trim();
      const id = name.toLowerCase().replace(/[^a-z0-9]+/g, '-') || a.id;
      const sessionName = s.sessionName ?? 'Session';
      const person: Person = {
        id,
        name,
        initials: initialsOf(name),
        role: a.cue.trim() || undefined,
        firstMet: { event: sessionName, date: TODAY },
        lastSeen: { event: sessionName, date: TODAY },
        leftOff: a.cue.trim() ? { when: `${TODAY} · ${sessionName}`, text: a.cue.trim() } : undefined,
        notes: [],
        conversations: [{ id: `c-${id}`, event: sessionName, when: TODAY, mins: 4 }],
        savedTonight: true,
      };
      return {
        ...s,
        minutes: Math.max(s.minutes, T.priyaSaved),
        drafts: s.drafts.filter((d) => d.id !== a.id),
        activeDraftId: null,
        people: [person, ...s.people.filter((p) => p.id !== id)],
        toast: { title: `${name} saved`, sub: 'Audio deleted · voiceprint on this iPhone', initials: person.initials },
      };
    }
    case 'discardDraft':
      return {
        ...s,
        drafts: s.drafts.filter((d) => d.id !== a.id),
        activeDraftId: null,
        toast: { title: 'Voice discarded', sub: 'The audio was deleted.' },
      };
    case 'declineLatest': {
      const latest = [...s.drafts].sort((x, y) => y.heardMin - x.heardMin)[0];
      return {
        ...s,
        drafts: latest ? s.drafts.filter((d) => d.id !== latest.id) : s.drafts,
        toast: latest
          ? { title: 'Their voice was discarded', sub: 'Nothing about them was saved.' }
          : { title: 'Nothing to discard', sub: 'No unsaved voices from this session.' },
      };
    }
    case 'addTask':
      return s.tasks.includes(a.id) ? s : { ...s, tasks: [...s.tasks, a.id], toast: { title: 'Added to Familiar tasks' } };
    case 'addNote':
      return {
        ...s,
        people: s.people.map((p) =>
          p.id === a.personId ? { ...p, notes: [{ when: `${TODAY} · ${s.sessionName ?? 'Note'}`, text: a.text }, ...p.notes] } : p,
        ),
        toast: { title: 'Note added' },
      };
    case 'openPerson':
      return { ...s, activePersonId: a.id };
    case 'deleteConversation':
      return {
        ...s,
        people: s.people.map((p) =>
          p.id === a.personId ? { ...p, conversations: p.conversations.filter((c) => c.id !== a.conversationId) } : p,
        ),
        toast: { title: 'Conversation deleted' },
      };
    case 'forget': {
      const p = s.people.find((x) => x.id === a.personId);
      return {
        ...s,
        people: s.people.filter((x) => x.id !== a.personId),
        match: s.match?.personId === a.personId ? null : s.match,
        toast: { title: `${p?.name.split(' ')[0] ?? 'They'} forgotten`, sub: 'Notes and voiceprint deleted.' },
      };
    }
    case 'forgetAll':
      return { ...s, people: [], drafts: [], match: null, toast: { title: 'Everyone forgotten', sub: 'All notes and voiceprints deleted.' } };
    case 'toast':
      return { ...s, toast: a.toast };
    case 'reset':
      return a.state;
  }
}

// ---------- Derived helpers ----------
export const selectors = {
  person: (s: State, id: string | undefined | null) => s.people.find((p) => p.id === id),
  matched: (s: State) => (s.match ? s.people.find((p) => p.id === s.match!.personId) : undefined),
  activeDraft: (s: State) =>
    s.drafts.find((d) => d.id === s.activeDraftId) ??
    [...s.drafts].sort((a, b) => Number(!!b.quote) - Number(!!a.quote) || b.heardMin - a.heardMin)[0],
  visibleFollowUps: (s: State) => followUps.filter((f) => !f.needs || s.people.some((p) => p.id === f.needs)),
  recentPeople: (s: State) =>
    [...s.people].sort((a, b) => Number(b.lastSeen.date === TODAY) - Number(a.lastSeen.date === TODAY)),
};

// ---------- Context ----------
interface Ctx {
  state: State;
  dispatch: (a: Action) => void;
  go: (route: string) => void;
  back: () => void;
  interactive: boolean;
}
const StoreCtx = createContext<Ctx | null>(null);

export function StoreProvider({
  initial, go, back, interactive = true, children,
}: {
  initial: State;
  go?: (route: string) => void;
  back?: () => void;
  interactive?: boolean;
  children: ReactNode;
}) {
  const [state, dispatch] = useReducer(reducer, initial);

  // Re-seed when a different preset is loaded from the viewer.
  useEffect(() => { dispatch({ type: 'reset', state: initial }); }, [initial]);

  // Toasts dismiss themselves in the live prototype.
  useEffect(() => {
    if (!interactive || !state.toast) return;
    const t = setTimeout(() => dispatch({ type: 'toast', toast: null }), 3600);
    return () => clearTimeout(t);
  }, [state.toast, interactive]);

  const value = useMemo<Ctx>(
    () => ({ state, dispatch, go: go ?? (() => {}), back: back ?? (() => {}), interactive }),
    [state, go, back, interactive],
  );
  return <StoreCtx.Provider value={value}>{children}</StoreCtx.Provider>;
}

export function useStore(): Ctx {
  const ctx = useContext(StoreCtx);
  if (!ctx) throw new Error('useStore must be used inside <StoreProvider>');
  return ctx;
}
