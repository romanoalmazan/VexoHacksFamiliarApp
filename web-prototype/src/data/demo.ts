// Demo content for the Familiar prototype, shaped like the server's data (see ../../server).
//
// Server person record (faces.py + profiles.py):
//   { name, relationship, photos, recall, facts[], follow_ups[], last_seen, visits[{at, recall}] }
// Server face match:      { name, relationship, match: "sure" | "possible", recall }
// Server transcript line: { speaker, text } — or { speaker, text: "", hidden: true } for anyone
//                         who is not registered (never shown, never saved).
//
// The story: Eleanor lives with memory loss. She wears the band and the glasses. Her daughter
// Maria visits; the glasses see Maria, the band hears her, and Familiar says who she is.

export interface Visit { at: string; recall: string }
export interface Person {
  name: string;                 // also the id, as on the server
  relationship: string;         // "daughter", "neighbour" — said out loud: "This is Maria, your daughter."
  photos: number;               // face photos enrolled (the server keeps face numbers, not photos)
  recall: string;               // one warm sentence about the last conversation (Gemini)
  facts: string[];              // up to 5 lasting facts
  followUps: string[];          // up to 2 things to ask about next time
  lastSeen: string | null;      // "Today, 2:14 PM", "Oct 30"
  visits: Visit[];              // recent visits, newest first
}

export type Speaker = 'me' | string | null;   // 'me' = the wearer, a name, or null = not registered
export interface Line { speaker: Speaker; text: string; hidden?: boolean }

export const WEARER = 'Eleanor';
export const DEMO_DATE = 'Saturday, November 14';
export const LISTEN_START_MIN = 14 * 60;      // Listen switched on at 2:00 PM

/** Key moments, in minutes after Listen was switched on. */
export const T = {
  mariaInView: 14,     // 2:14 PM — glasses see Maria, the band hears her
  conversationEnd: 31, // 2:31 PM
};

export function clock(minutesIn: number, withPeriod = false): string {
  const total = LISTEN_START_MIN + minutesIn;
  const h24 = Math.floor(total / 60) % 24;
  const m = total % 60;
  const h12 = h24 % 12 === 0 ? 12 : h24 % 12;
  return `${h12}:${String(m).padStart(2, '0')}${withPeriod ? (h24 >= 12 ? ' PM' : ' AM') : ''}`;
}

export function duration(mins: number): string {
  if (mins < 60) return `${mins} min`;
  return `${Math.floor(mins / 60)} h ${mins % 60} min`;
}

export function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return '?';
  return (parts[0][0] + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase();
}

/** "This is Maria, your daughter." — the line the app speaks and shows. */
export function introLine(p: Pick<Person, 'name' | 'relationship'>): string {
  return p.relationship ? `This is ${p.name}, your ${p.relationship}.` : `This is ${p.name}.`;
}

export const initialPeople: Person[] = [
  {
    name: 'Maria',
    relationship: 'daughter',
    photos: 4,
    recall: 'Last time, Maria told you about Leo’s graduation next Saturday.',
    facts: ['Lives in Portland with her husband Sam', 'Her son Leo is graduating from high school', 'Works as a nurse'],
    followUps: ['Ask how Leo’s graduation went', 'Ask about Sam’s new job'],
    lastSeen: 'Nov 7',
    visits: [
      { at: 'Nov 7', recall: 'Maria told you about Leo’s graduation next Saturday.' },
      { at: 'Oct 31', recall: 'You looked at old photos of the lake house together.' },
    ],
  },
  {
    name: 'Leo',
    relationship: 'grandson',
    photos: 3,
    recall: 'Leo showed you his robotics project and asked about your garden.',
    facts: ['Maria’s son, 18', 'Builds robots at school', 'Starts college in the fall'],
    followUps: ['Ask which college he chose'],
    lastSeen: 'Oct 31',
    visits: [{ at: 'Oct 31', recall: 'Leo showed you his robotics project.' }],
  },
  {
    name: 'Ruth',
    relationship: 'neighbour',
    photos: 3,
    recall: 'Ruth brought lemon cake and said her cat, Biscuit, is unwell.',
    facts: ['Lives next door', 'Has a cat called Biscuit', 'Waters your plants when you travel'],
    followUps: ['Ask how Biscuit is feeling'],
    lastSeen: 'Nov 12',
    visits: [{ at: 'Nov 12', recall: 'Ruth brought lemon cake and said Biscuit is unwell.' }],
  },
  {
    name: 'Dr. Patel',
    relationship: 'doctor',
    photos: 2,
    recall: 'Dr. Patel checked your blood pressure and said it looks good.',
    facts: ['Your doctor at Riverside Clinic'],
    followUps: [],
    lastSeen: 'Oct 22',
    visits: [{ at: 'Oct 22', recall: 'Dr. Patel said your blood pressure looks good.' }],
  },
];

/** What the band hears once Maria is in view (names resolved by face + voice, as in who.py). */
export const visitLines: Line[] = [
  { speaker: 'me', text: 'Oh, hello! Come in, come in.' },
  { speaker: 'Maria', text: 'Hi Mum. I brought the photos from Leo’s graduation.' },
  { speaker: null, text: '', hidden: true },
  { speaker: 'me', text: 'Let me see! Was it a nice day?' },
  { speaker: 'Maria', text: 'It was lovely. He gave a speech and thanked you.' },
];

/** What Gemini writes for Maria when the conversation ends (profiles.py). */
export const mariaAfterVisit: Pick<Person, 'recall' | 'facts' | 'followUps'> = {
  recall: 'Maria brought photos from Leo’s graduation. Leo gave a speech and thanked you.',
  facts: ['Lives in Portland with her husband Sam', 'Her son Leo graduated from high school', 'Works as a nurse'],
  followUps: ['Ask to see the graduation photos again', 'Ask about Sam’s new job'],
};
