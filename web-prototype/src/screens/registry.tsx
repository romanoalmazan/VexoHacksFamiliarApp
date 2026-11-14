import type { ComponentType } from 'react';
import { type Action, type State, baseState, reducer } from '../state/store';
import { CameraScreen, PairScreen, SetupPrivacyScreen, VoiceScreen, WelcomeScreen } from './Setup';
import { DynamicIslandScreen, LockScreen, NowScreen } from './Event';
import { PossibleMatchScreen, RecognizedScreen, RegisterScreen } from './Recognition';
import { PeopleScreen, ProfileScreen, RecapScreen } from './After';
import { PrivacyTabScreen, ShowSomeoneScreen } from './Privacy';
import { HeroScreen } from './Hero';
import { ConnectScreen } from './Account';
import { SettingsScreen } from './Settings';
import { BrandScreen } from './Brand';

/** App routes → the component that renders them. */
export const routes: Record<string, ComponentType> = {
  hero: HeroScreen,
  brand: BrandScreen,
  welcome: WelcomeScreen,
  connect: ConnectScreen,
  pair: PairScreen,
  'setup-privacy': SetupPrivacyScreen,
  camera: CameraScreen,
  voice: VoiceScreen,
  now: NowScreen,
  lock: LockScreen,
  island: DynamicIslandScreen,
  recognized: RecognizedScreen,
  'possible-match': PossibleMatchScreen,
  register: RegisterScreen,
  recap: RecapScreen,
  people: PeopleScreen,
  profile: ProfileScreen,
  'show-someone': ShowSomeoneScreen,
  privacy: PrivacyTabScreen,
  settings: SettingsScreen,
};

const run = (from: State, ...actions: Action[]) => actions.reduce(reducer, from);

// Demo states, built by replaying real app actions so they stay consistent.
const connected = run(baseState, { type: 'connect', address: 'ws://familiar-laptop.local:8765', code: '482193' });
const paired = run(connected, { type: 'pair', id: '64', pretend: false });
const cameraSet = run(paired, { type: 'setCamera', camera: 'glasses' }, { type: 'linkGlasses' }, { type: 'toast', toast: null });
const ready = run(cameraSet, { type: 'registerVoice', seconds: 10.8 }, { type: 'toast', toast: null });
const listening = run(ready, { type: 'startListening' });
const after = run(listening, { type: 'stopListening' }, { type: 'toast', toast: null });

export const presets = {
  base: baseState,
  connected,
  paired,
  cameraSet,
  ready,
  listening,
  listeningUnregistered: run(listening, { type: 'simUnregistered' }),
  lockDetail: run(listening, { type: 'setLock', mode: 'details' }),
  possible: run(ready, { type: 'simFace', name: 'Leo', match: 'possible' }),
  after,
  // Only the wearer and someone unregistered talked: the server keeps nothing.
  afterNobody: run(
    { ...ready, listening: true, minutes: 9, transcript: [{ speaker: 'me', text: 'Thank you, just leave it by the door.' }, { speaker: null, text: '', hidden: true }, { speaker: null, text: '', hidden: true }] },
    { type: 'stopListening' }, { type: 'toast', toast: null },
  ),
  profile: run(after, { type: 'openPerson', name: 'Maria' }),
  settingsLight: run(ready, { type: 'setAppearance', appearance: 'light' }),
  settingsDark: run(ready, { type: 'setAppearance', appearance: 'dark' }),
  listeningDark: run(listening, { type: 'setAppearance', appearance: 'dark' }),
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
    boards: [{ id: 'hero', num: '00', title: 'Pitch hero (16:9)', route: 'hero', preset: presets.listening, w: 1920, h: 1080, kind: 'hero' }],
  },
  {
    title: 'Setup · 1–4',
    boards: [
      { id: 'welcome', num: '01', title: 'Welcome', route: 'welcome', preset: presets.base, ...phone },
      { id: 'connect', num: '01b', title: 'Connect to your server', route: 'connect', preset: presets.base, ...phone },
      { id: 'pair', num: '02', title: 'Pair band', route: 'pair', preset: presets.connected, ...phone },
      { id: 'setup-privacy', num: '03', title: 'How Familiar listens', route: 'setup-privacy', preset: presets.paired, ...phone },
      { id: 'camera', num: '04', title: 'Choose a camera', route: 'camera', preset: presets.paired, ...phone },
      { id: 'voice', num: '04b', title: 'Register my voice', route: 'voice', preset: presets.cameraSet, ...phone },
    ],
  },
  {
    title: 'Listening · 5–7',
    boards: [
      { id: 'now-ready', num: '05', title: 'Now — ready', route: 'now', preset: presets.ready, ...phone },
      { id: 'now-live', num: '06', title: 'Now — listening, Maria in view', route: 'now', preset: presets.listeningUnregistered, ...phone },
      { id: 'lock-private', num: '07a', title: 'Lock Screen — private (default)', route: 'lock', preset: presets.listening, ...phone },
      { id: 'lock-detail', num: '07b', title: 'Lock Screen — details (opt-in)', route: 'lock', preset: presets.lockDetail, ...phone },
      { id: 'island', num: '07c', title: 'Dynamic Island', route: 'island', preset: presets.listening, w: 390, h: 680, kind: 'board' },
    ],
  },
  {
    title: 'Recognition · 8–10',
    boards: [
      { id: 'recognized', num: '08', title: 'This is Maria (face match: sure)', route: 'recognized', preset: presets.listening, ...phone },
      { id: 'possible-match', num: '09', title: 'Might be Leo (face match: possible)', route: 'possible-match', preset: presets.possible, ...phone },
      { id: 'register', num: '10', title: 'Register a person', route: 'register', preset: presets.ready, ...phone },
    ],
  },
  {
    title: 'After the conversation · 11–12',
    boards: [
      { id: 'recap', num: '11', title: 'Conversation — what to remember', route: 'recap', preset: presets.after, ...phone },
      { id: 'recap-nobody', num: '11b', title: 'Conversation — nobody registered', route: 'recap', preset: presets.afterNobody, ...phone },
      { id: 'people', num: '12a', title: 'People & faces', route: 'people', preset: presets.after, ...phone },
      { id: 'profile', num: '12b', title: 'Profile — Maria', route: 'profile', preset: presets.profile, ...phone },
    ],
  },
  {
    title: 'Privacy and settings · 13–15',
    boards: [
      { id: 'show-someone', num: '13', title: 'Show someone what Familiar does', route: 'show-someone', preset: presets.listening, ...phone },
      { id: 'privacy', num: '14', title: 'Privacy tab', route: 'privacy', preset: presets.listening, ...phone },
      { id: 'settings', num: '15', title: 'Settings — light', route: 'settings', preset: presets.settingsLight, ...phone, theme: 'light' },
      { id: 'settings-dark', num: '15b', title: 'Settings — dark', route: 'settings', preset: presets.settingsDark, ...phone, theme: 'dark' },
      { id: 'now-dark', num: '06d', title: 'Now — listening, dark', route: 'now', preset: presets.listeningDark, ...phone, theme: 'dark' },
    ],
  },
];

export const boards: Board[] = rows.flatMap((r) => r.boards);
export const boardById = (id: string) => boards.find((b) => b.id === id);
