import { createContext, useContext, useEffect, useMemo, useReducer, type ReactNode } from 'react';
import { type Line, type Person, T, initialPeople, mariaAfterVisit, visitLines, clock } from '../data/demo';

// App state for the prototype. Each action mirrors something the real app does with the
// server (server/server.py): pair with a code, stream while Listen is on, get face matches
// ("sure" / "possible"), enrol a person (consent required), forget a person.

export type LockMode = 'private' | 'name' | 'details';
export type Appearance = 'light' | 'dark' | 'system';
export type Match = 'sure' | 'possible';
export type Camera = 'glasses' | 'iphone';
export interface Toast { title: string; sub?: string; initials?: string }

export interface Conversation {
  people: string[];      // registered people who took part
  kept: number;          // lines kept (wearer + registered people)
  hidden: number;        // lines from people who are not registered: not kept
  minutes: number;
}

export interface State {
  appearance: Appearance;
  server: { address: string; code: string } | null;   // ws://… + 6-digit pairing code
  band: { id: string; pretend: boolean } | null;
  camera: Camera | null;
  glassesLinked: boolean;
  speak: boolean;                                      // "Say who it is out loud"
  listening: boolean;                                  // the Listen toggle
  minutes: number;                                     // minutes since Listen (demo clock)
  lockMode: LockMode;
  inView: { name: string; match: Match } | null;       // what the camera sees right now
  transcript: Line[];
  people: Person[];
  activePerson: string;
  toast: Toast | null;
  lastConversation: Conversation | null;
}

export const baseState: State = {
  appearance: 'system',
  server: null,
  band: null,
  camera: null,
  glassesLinked: false,
  speak: true,
  listening: false,
  minutes: 0,
  lockMode: 'private',
  inView: null,
  transcript: [],
  people: initialPeople,
  activePerson: 'Maria',
  toast: null,
  lastConversation: null,
};

export type Action =
  | { type: 'connect'; address: string; code: string }
  | { type: 'disconnect' }
  | { type: 'pair'; id: string; pretend: boolean }
  | { type: 'setCamera'; camera: Camera }
  | { type: 'linkGlasses' }
  | { type: 'setSpeak'; on: boolean }
  | { type: 'startListening' }
  | { type: 'stopListening' }
  | { type: 'simFace'; name: string; match: Match }
  | { type: 'confirmFace' }
  | { type: 'rejectFace' }
  | { type: 'simUnregistered' }
  | { type: 'register'; name: string; relationship: string; photos: number }
  | { type: 'forget'; name: string }
  | { type: 'forgetAll' }
  | { type: 'openPerson'; name: string }
  | { type: 'setLock'; mode: LockMode }
  | { type: 'setAppearance'; appearance: Appearance }
  | { type: 'toast'; toast: Toast | null }
  | { type: 'reset'; state: State };

function seen(people: Person[], name: string, minutes: number): Person[] {
  return people.map((p) => (p.name === name ? { ...p, lastSeen: `Today, ${clock(minutes, true)}` } : p));
}

export function reducer(s: State, a: Action): State {
  switch (a.type) {
    case 'connect':
      return { ...s, server: { address: a.address.trim(), code: a.code } };
    case 'disconnect':
      return { ...s, server: null, listening: false, inView: null, toast: { title: 'Disconnected from the server' } };
    case 'pair':
      return { ...s, band: { id: a.id, pretend: a.pretend } };
    case 'setCamera':
      return { ...s, camera: a.camera };
    case 'linkGlasses':
      return { ...s, glassesLinked: true, toast: { title: 'Meta glasses linked', sub: 'Meta AI approved Familiar.' } };
    case 'setSpeak':
      return { ...s, speak: a.on };

    case 'startListening':
      // The demo skips ahead to the moment Maria walks in: the glasses see her, the band hears her.
      return {
        ...s,
        listening: true,
        minutes: T.mariaInView,
        inView: { name: 'Maria', match: 'sure' },
        transcript: visitLines,
        people: seen(s.people, 'Maria', T.mariaInView),
        lastConversation: null,
        toast: null,
      };
    case 'stopListening': {
      // As the server does when streaming stops: keep only the wearer's and registered people's
      // words; nothing at all if no registered person took part; Gemini updates their profiles.
      const people = [...new Set(s.transcript.map((l) => l.speaker).filter((x): x is string => !!x && x !== 'me'))];
      const hidden = s.transcript.filter((l) => l.hidden).length;
      const kept = people.length ? s.transcript.length - hidden : 0;
      const minutes = Math.max(s.minutes, T.conversationEnd);
      const updated = s.people.map((p) => {
        if (!people.includes(p.name)) return p;
        const learned = p.name === 'Maria' ? mariaAfterVisit : { recall: `You talked with ${p.name} today.`, facts: p.facts, followUps: p.followUps };
        return { ...p, ...learned, visits: [{ at: 'Today', recall: learned.recall }, ...p.visits].slice(0, 5) };
      });
      return {
        ...s,
        listening: false,
        inView: null,
        transcript: [],
        minutes,
        people: updated,
        lastConversation: { people, kept, hidden, minutes },
        toast: people.length
          ? { title: 'Conversation saved as text', sub: `${people.join(', ')} · no audio kept` }
          : { title: 'Nothing was kept', sub: 'Nobody registered took part.' },
      };
    }

    case 'simFace': {
      const listening = s.listening ? {} : { listening: true, minutes: T.mariaInView };
      const next: State = { ...s, ...listening, inView: { name: a.name, match: a.match } };
      if (a.match !== 'sure') return next;
      const line: Line = { speaker: a.name, text: 'Hello! It’s good to see you.' };
      return { ...next, people: seen(next.people, a.name, next.minutes), transcript: [...next.transcript, line] };
    }
    case 'confirmFace':
      if (!s.inView) return s;
      return { ...s, inView: { ...s.inView, match: 'sure' }, people: seen(s.people, s.inView.name, s.minutes) };
    case 'rejectFace':
      return { ...s, inView: null, toast: { title: 'Okay — no name shown', sub: 'Nothing was added to their profile.' } };
    case 'simUnregistered':
      return { ...s, transcript: [...s.transcript, { speaker: null, text: '', hidden: true }] };

    case 'register': {
      const name = a.name.trim();
      const person: Person = {
        name, relationship: a.relationship.trim(), photos: a.photos,
        recall: '', facts: [], followUps: [], lastSeen: null, visits: [],
      };
      return {
        ...s,
        people: [person, ...s.people.filter((p) => p.name !== name)],
        activePerson: name,
        toast: { title: `${name} is registered`, sub: 'Recognised from now on.', initials: name.slice(0, 1).toUpperCase() },
      };
    }
    case 'forget':
      return {
        ...s,
        people: s.people.filter((p) => p.name !== a.name),
        inView: s.inView?.name === a.name ? null : s.inView,
        toast: { title: `Forgot ${a.name}`, sub: 'Face data and profile deleted on the server.' },
      };
    case 'forgetAll':
      return { ...s, people: [], inView: null, toast: { title: 'Everyone forgotten', sub: 'All face data and profiles deleted.' } };
    case 'openPerson':
      return { ...s, activePerson: a.name };
    case 'setLock':
      return { ...s, lockMode: a.mode };
    case 'setAppearance':
      return { ...s, appearance: a.appearance };
    case 'toast':
      return { ...s, toast: a.toast };
    case 'reset':
      return a.state;
  }
}

// ---------- Derived helpers ----------
export const selectors = {
  person: (s: State, name: string | null | undefined) => s.people.find((p) => p.name === name),
  inViewPerson: (s: State) => (s.inView ? s.people.find((p) => p.name === s.inView!.name) : undefined),
  recentPeople: (s: State) =>
    [...s.people].sort((a, b) => Number((b.lastSeen ?? '').startsWith('Today')) - Number((a.lastSeen ?? '').startsWith('Today'))),
  ready: (s: State) => !!s.server && !!s.band && !!s.camera,
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
