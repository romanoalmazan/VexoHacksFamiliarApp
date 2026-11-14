import type { ComponentType } from 'react';
import { type Action, type State, baseState, reducer } from '../state/store';
import { PairScreen, SetupPrivacyScreen, VoiceScreen, WelcomeScreen } from './Setup';
import { DynamicIslandScreen, LockScreen, NowScreen } from './Event';
import { NewVoiceScreen, PossibleMatchScreen, RecognizedScreen } from './Recognition';
import { PeopleScreen, ProfileScreen, RecapScreen } from './After';
import { PrivacyTabScreen, ShowSomeoneScreen } from './Privacy';
import { HeroScreen } from './Hero';
import { SignUpScreen, VerifyScreen } from './Account';
import { SettingsScreen } from './Settings';
import { BrandScreen } from './Brand';

/** App routes → the component that renders them. */
export const routes: Record<string, ComponentType> = {
  hero: HeroScreen,
  brand: BrandScreen,
  welcome: WelcomeScreen,
  signup: SignUpScreen,
  verify: VerifyScreen,
  pair: PairScreen,
  'setup-privacy': SetupPrivacyScreen,
  voice: VoiceScreen,
  now: NowScreen,
  lock: LockScreen,
  island: DynamicIslandScreen,
  recognized: RecognizedScreen,
  'possible-match': PossibleMatchScreen,
  'new-voice': NewVoiceScreen,
  recap: RecapScreen,
  people: PeopleScreen,
  profile: ProfileScreen,
  'show-someone': ShowSomeoneScreen,
  privacy: PrivacyTabScreen,
  settings: SettingsScreen,
};

const run = (from: State, ...actions: Action[]) => actions.reduce(reducer, from);

// Demo states, built by replaying real app actions so they stay consistent.
const paired = run(baseState, { type: 'pair', band: '4F2A' });
const live = run(paired, { type: 'nameSession' }, { type: 'startSession' });
const priyaSaved = run(live, { type: 'saveDraft', id: 'd-priya', name: 'Priya', cue: 'Works on gripper design' });
const after = run(priyaSaved, { type: 'toast', toast: null }, { type: 'endSession' });

export const presets = {
  base: baseState,
  signedUp: run(baseState, { type: 'signUp', name: 'Alex Rivera', email: 'alex@hey.com', method: 'email' }),
  sample2: run(baseState, { type: 'pair', band: '4F2A' }, { type: 'nextSample' }),
  paired,
  live,
  lockDetail: run(live, { type: 'setLock', mode: 'details' }),
  unsure: run(live, { type: 'simMatch', personId: 'maya', confidence: 'unsure' }),
  newVoice: run(live, { type: 'openDraft', id: 'd-priya' }),
  saved: priyaSaved,
  after,
  settingsLight: run(paired, { type: 'signUp', name: 'Alex Rivera', email: 'alex@hey.com', method: 'email' }, { type: 'verifyEmail' }, { type: 'setAppearance', appearance: 'light' }),
  settingsDark: run(paired, { type: 'signUp', name: 'Alex Rivera', email: 'alex@hey.com', method: 'email' }, { type: 'verifyEmail' }, { type: 'setAppearance', appearance: 'dark' }),
  liveDark: run(live, { type: 'setAppearance', appearance: 'dark' }),
  profile: run(after, { type: 'addTask', id: 'f-portfolio' }, { type: 'toast', toast: null }, { type: 'openPerson', id: 'maya' }),
};

export interface Board {
  id: string;
  num: string;
  title: string;
  route: string;
  preset: State;
  w: number;
  h: number;
  kind?: 'phone' | 'board' | 'hero' | 'brand';
  theme?: 'light' | 'dark';   // force a theme on the canvas, whatever the canvas toggle says
}
export interface Row { title: string; boards: Board[] }

const phone = { w: 390, h: 844, kind: 'phone' as const };

export const rows: Row[] = [
  {
    title: 'Brand',
    boards: [{ id: 'brand', num: '00b', title: 'Logo — The Overlap', route: 'brand', preset: baseState, w: 1440, h: 680, kind: 'brand' }],
  },
  {
    title: 'Pitch hero',
    boards: [{ id: 'hero', num: '00', title: 'Pitch hero (16:9)', route: 'hero', preset: presets.live, w: 1920, h: 1080, kind: 'hero' }],
  },
  {
    title: 'Account and setup · 1–4',
    boards: [
      { id: 'welcome', num: '01', title: 'Welcome', route: 'welcome', preset: presets.base, ...phone },
      { id: 'signup', num: '01b', title: 'Sign up', route: 'signup', preset: presets.base, ...phone },
      { id: 'verify', num: '01c', title: 'Verify email', route: 'verify', preset: presets.signedUp, ...phone },
      { id: 'pair', num: '02', title: 'Pair band', route: 'pair', preset: presets.signedUp, ...phone },
      { id: 'setup-privacy', num: '03', title: 'Privacy', route: 'setup-privacy', preset: presets.paired, ...phone },
      { id: 'voice', num: '04', title: 'Teach your voice', route: 'voice', preset: presets.sample2, ...phone },
    ],
  },
  {
    title: 'At the event · 5–7',
    boards: [
      { id: 'now-ready', num: '05', title: 'Now — ready', route: 'now', preset: presets.paired, ...phone },
      { id: 'now-live', num: '06', title: 'Now — live', route: 'now', preset: presets.live, ...phone },
      { id: 'lock-private', num: '07a', title: 'Lock Screen — private (default)', route: 'lock', preset: presets.live, ...phone },
      { id: 'lock-detail', num: '07b', title: 'Lock Screen — detail (opt-in)', route: 'lock', preset: presets.lockDetail, ...phone },
      { id: 'island', num: '07c', title: 'Dynamic Island — compact and expanded', route: 'island', preset: presets.live, w: 390, h: 680, kind: 'board' },
    ],
  },
  {
    title: 'Recognition · 8–10',
    boards: [
      { id: 'recognized', num: '08', title: 'Recognized', route: 'recognized', preset: presets.live, ...phone },
      { id: 'possible-match', num: '09', title: 'Possible match', route: 'possible-match', preset: presets.unsure, ...phone },
      { id: 'new-voice', num: '10', title: 'New voice', route: 'new-voice', preset: presets.newVoice, ...phone },
      { id: 'now-saved', num: '10b', title: 'Now — Priya saved', route: 'now', preset: presets.saved, ...phone },
    ],
  },
  {
    title: 'After the event · 11–12',
    boards: [
      { id: 'recap', num: '11', title: 'Recap', route: 'recap', preset: presets.after, ...phone },
      { id: 'people', num: '12a', title: 'People', route: 'people', preset: presets.after, ...phone },
      { id: 'profile', num: '12b', title: 'Profile', route: 'profile', preset: presets.profile, ...phone },
    ],
  },
  {
    title: 'Privacy, consent and settings · 13–15',
    boards: [
      { id: 'show-someone', num: '13', title: 'Show someone what Familiar does', route: 'show-someone', preset: presets.live, ...phone },
      { id: 'privacy', num: '14', title: 'Privacy tab', route: 'privacy', preset: presets.live, ...phone },
      { id: 'settings', num: '15', title: 'Settings — light', route: 'settings', preset: presets.settingsLight, ...phone, theme: 'light' },
      { id: 'settings-dark', num: '15b', title: 'Settings — dark', route: 'settings', preset: presets.settingsDark, ...phone, theme: 'dark' },
      { id: 'now-dark', num: '06d', title: 'Now — live, dark', route: 'now', preset: presets.liveDark, ...phone, theme: 'dark' },
    ],
  },
];

export const boards: Board[] = rows.flatMap((r) => r.boards);
export const boardById = (id: string) => boards.find((b) => b.id === id);
