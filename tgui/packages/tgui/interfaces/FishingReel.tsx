import { useEffect } from 'react';
import { Box, NoticeBox, ProgressBar, Section, Stack } from 'tgui-core/components';
import { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type ReelData = {
  fighting: BooleanLike;
  tension: number;
  max_tension: number;
  distance: number;
  max_distance: number;
  fish_state: string;
  hint: string;
  reeling: BooleanLike;
};

// What to tell the angler for each thing the fish can be doing, and how urgent it is
const FISH_STATES = {
  'resting': { text: "It's resting. Reel!", color: 'good' },
  'tensing': { text: "It's about to run!", color: 'average' },
  'running': { text: "It's running. Ease off!", color: 'bad' },
  'worn out': { text: "It's worn out. Reel it in!", color: 'good' },
};

export const FishingReel = (props) => {
  const { act, data } = useBackend<ReelData>();
  const { fighting, tension, max_tension, distance, max_distance, fish_state, hint, reeling } = data;

  // Letting go of the mouse anywhere stops the reel, not just over the button
  useEffect(() => {
    const letGo = () => act('reel', { held: false });
    window.addEventListener('mouseup', letGo);
    return () => window.removeEventListener('mouseup', letGo);
  }, []);

  if (!fighting) {
    return (
      <Window width={340} height={120}>
        <Window.Content>
          <NoticeBox>There is nothing on the line.</NoticeBox>
        </Window.Content>
      </Window>
    );
  }

  const fishState = FISH_STATES[fish_state] || FISH_STATES['resting'];
  return (
    <Window width={340} height={305}>
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Section title={"There's " + hint + ' on the line'}>
              <Box bold fontSize={1.3} textAlign="center" color={fishState.color}>
                {fishState.text}
              </Box>
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section>
              <Box mb={0.5}>Line strain. The line snaps if this fills up.</Box>
              <ProgressBar
                minValue={0}
                maxValue={max_tension}
                value={tension}
                ranges={{
                  good: [0, max_tension * 0.6],
                  average: [max_tension * 0.6, max_tension * 0.85],
                  bad: [max_tension * 0.85, max_tension],
                }}
              >
                {tension}%
              </ProgressBar>
              <Box mt={1} mb={0.5}>
                Line out. It gets away if this fills up, and it&apos;s yours at zero.
              </Box>
              <ProgressBar
                minValue={0}
                maxValue={max_distance}
                value={distance}
                ranges={{
                  good: [0, max_distance * 0.5],
                  average: [max_distance * 0.5, max_distance * 0.8],
                  bad: [max_distance * 0.8, max_distance],
                }}
              >
                {distance.toFixed(1)} tiles
              </ProgressBar>
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            <Box
              className={'Button Button--fluid ' + (reeling ? 'Button--selected' : 'Button--color--default')}
              height="100%"
              textAlign="center"
              fontSize={1.4}
              bold
              style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', userSelect: 'none' }}
              onMouseDown={(event) => {
                event.preventDefault();
                act('reel', { held: true });
              }}
            >
              {reeling ? 'Reeling...' : 'Hold to reel'}
            </Box>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
