// Demo content for the Familiar prototype. One timeline drives every time shown
// on screen, so the Lock Screen, "heard at", session length and recap agree.

export interface Note { when: string; text: string }
export interface Conversation { id: string; event: string; when: string; mins: number }
export interface Person {
  id: string;
  name: string;
  initials: string;
  role?: string;
  firstMet: { event: string; date: string };
  lastSeen: { event: string; date: string };
  leftOff?: Note;          // the headline "where you left off"
  notes: Note[];           // older context, newest first
  conversations: Conversation[];
  savedTonight?: boolean;
}
export interface Draft {
  id: string;
  heardMin: number;        // minutes into the session
  quote?: string;          // what was transcribed, if a name was heard
  name: string;
  cue: string;
}
export interface FollowUp { id: string; text: string; needs?: string }

/** Builders Night starts at 6:30 PM. */
export const SESSION_START_MIN = 18 * 60 + 30;
export const DEMO_DATE = 'Saturday, November 14';
export const CALENDAR_EVENT = { name: 'Builders Night', when: 'Today · 6:30 PM' };

/** Key moments of the demo, in minutes after the session starts. */
export const T = {
  unnamedHeard: 18,   // 6:48 PM — someone spoke, no name heard
  priyaHeard: 22,     // 6:52 PM — "Hi, I'm Priya"
  mayaDetected: 26,   // 6:56 PM — wrist tap, Lock Screen
  priyaSaved: 31,     // 7:01 PM
  sessionEnd: 72,     // 7:42 PM — 1 h 12 min
};

export function clock(minutesIntoSession: number, withPeriod = false): string {
  const total = SESSION_START_MIN + minutesIntoSession;
  const h24 = Math.floor(total / 60) % 24;
  const m = total % 60;
  const h12 = h24 % 12 === 0 ? 12 : h24 % 12;
  return `${h12}:${String(m).padStart(2, '0')}${withPeriod ? (h24 >= 12 ? ' PM' : ' AM') : ''}`;
}

export function duration(mins: number): string {
  if (mins < 60) return `${mins} min`;
  return `${Math.floor(mins / 60)} h ${mins % 60} min`;
}

export const initialPeople: Person[] = [
  {
    id: 'maya',
    name: 'Maya Chen',
    initials: 'MC',
    role: 'Product designer · Northline',
    firstMet: { event: 'Hardware Meetup', date: 'Oct 9' },
    lastSeen: { event: 'Hardware Meetup', date: 'Oct 9' },
    leftOff: { when: 'Oct 9 · Hardware Meetup', text: 'You offered to send your portfolio.' },
    notes: [{ when: 'Oct 9 · Hardware Meetup', text: 'She asked about gripper suppliers.' }],
    conversations: [{ id: 'c-maya-hm', event: 'Hardware Meetup', when: 'Oct 9', mins: 6 }],
  },
  {
    id: 'sam',
    name: 'Sam Whitfield',
    initials: 'SW',
    role: 'Firmware lead · Arcwell',
    firstMet: { event: 'Hardware Meetup', date: 'Oct 9' },
    lastSeen: { event: 'Hardware Meetup', date: 'Oct 9' },
    leftOff: { when: 'Oct 9 · Hardware Meetup', text: 'Recommended a BLE debugging tool.' },
    notes: [],
    conversations: [{ id: 'c-sam-hm', event: 'Hardware Meetup', when: 'Oct 9', mins: 9 }],
  },
  {
    id: 'daniel',
    name: 'Daniel Ortiz',
    initials: 'DO',
    role: 'Robotics engineer · Kinetic Labs',
    firstMet: { event: 'Robotics Mixer', date: 'Oct 2' },
    lastSeen: { event: 'Robotics Mixer', date: 'Oct 2' },
    leftOff: { when: 'Oct 2 · Robotics Mixer', text: 'Looking for a gripper engineer.' },
    notes: [],
    conversations: [{ id: 'c-daniel-rm', event: 'Robotics Mixer', when: 'Oct 2', mins: 11 }],
  },
  {
    id: 'lena',
    name: 'Lena Park',
    initials: 'LP',
    role: 'Founder · Tidepool',
    firstMet: { event: 'Founder Coffee', date: 'Sep 27' },
    lastSeen: { event: 'Founder Coffee', date: 'Sep 27' },
    leftOff: { when: 'Sep 27 · Founder Coffee', text: 'Asked for an intro to your investor.' },
    notes: [],
    conversations: [{ id: 'c-lena-fc', event: 'Founder Coffee', when: 'Sep 27', mins: 15 }],
  },
];

/** Voices heard during Builders Night before anyone is saved. */
export const sessionDrafts: Draft[] = [
  { id: 'd-unnamed', heardMin: T.unnamedHeard, name: '', cue: '' },
  {
    id: 'd-priya',
    heardMin: T.priyaHeard,
    quote: '“Hi, I’m Priya. I work on grippers.”',
    name: 'Priya',
    cue: 'Works on gripper design',
  },
];

export const followUps: FollowUp[] = [
  { id: 'f-portfolio', text: 'Send your portfolio to Maya' },
  { id: 'f-intro', text: 'Intro Priya to Daniel Ortiz', needs: 'priya' },
];

export function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return '?';
  return (parts[0][0] + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase();
}
