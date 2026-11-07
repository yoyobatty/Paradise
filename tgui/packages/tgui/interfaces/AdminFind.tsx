import { useEffect, useState } from 'react';
import { Box, Button, Input, NoticeBox, Section, Stack, Table } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Row = {
  uid: string;
  type: string;
  name: string;
  where?: string;
  movable?: boolean;
  invisible?: boolean;
  underfloor?: boolean;
  carrier?: string;
  ckey?: string;
};

type TypeCount = {
  type: string;
  count: number;
};

type Data = {
  mode: string;
  query: string;
  scope: string;
  radius: number;
  tile: string | null;
  here: string | null;
  inside: boolean;
  rows: Row[];
  counts: TypeCount[];
  matched: number;
  searched: boolean;
  took: number;
};

const MODES = [
  ['name', 'Name', 'Part of its name'],
  ['type', 'Type', 'A type path, with its subtypes'],
  ['ref', 'Ref', 'A ref or UID, like [0x2000123]'],
  ['player', 'Player', 'A ckey, or part of one'],
];

const SCOPES = [
  ['everywhere', 'Everywhere'],
  ['z', 'This z-level'],
  ['near', 'Near me'],
  ['tile', 'One tile'],
];

const PLACEHOLDERS = {
  name: 'Part of a name: crowbar, Bob, toolbox',
  type: 'A type path: /obj/item/gun',
  ref: 'A ref or UID: [0x2000123]',
  player: 'A ckey',
};

export const AdminFind = (props) => {
  const { act, data } = useBackend<Data>();
  const { mode, scope, inside, rows = [], counts = [], matched, searched, took } = data;
  const [query, setQuery] = useState(data.query || '');
  const [radius, setRadius] = useState(String(data.radius));
  const [tile, setTile] = useState(data.tile || '');

  // The server can change these too, like picking a tile from a result
  useEffect(() => setQuery(data.query || ''), [data.query]);
  useEffect(() => setTile(data.tile || ''), [data.tile]);

  const search = (change = {}) =>
    act('search', {
      mode,
      scope,
      inside: inside ? 1 : 0,
      query,
      radius,
      tile,
      ...change,
    });

  return (
    <Window width={900} height={640} title="Find">
      <Window.Content scrollable>
        <Section>
          <Stack align="center" mb={1}>
            {MODES.map(([key, label, tooltip]) => (
              <Stack.Item key={key}>
                <Button selected={mode === key} tooltip={tooltip} onClick={() => search({ mode: key })}>
                  {label}
                </Button>
              </Stack.Item>
            ))}
            <Stack.Item grow>
              <Input
                fluid
                value={query}
                placeholder={PLACEHOLDERS[mode]}
                onChange={(value) => setQuery(value)}
                onEnter={(value) => search({ query: value })}
              />
            </Stack.Item>
            <Stack.Item>
              <Button icon="search" onClick={() => search()}>
                Find
              </Button>
            </Stack.Item>
          </Stack>
          <Stack align="center">
            <Stack.Item color="label">Where</Stack.Item>
            {SCOPES.map(([key, label]) => (
              <Stack.Item key={key}>
                <Button selected={scope === key} onClick={() => search({ scope: key })}>
                  {label}
                </Button>
              </Stack.Item>
            ))}
            {scope === 'near' && (
              <>
                <Stack.Item>within</Stack.Item>
                <Stack.Item>
                  <Input
                    width="3rem"
                    value={radius}
                    onChange={(value) => setRadius(value)}
                    onEnter={(value) => search({ radius: value })}
                  />
                </Stack.Item>
                <Stack.Item>tiles</Stack.Item>
              </>
            )}
            {scope === 'tile' && (
              <>
                <Stack.Item>x, y, z</Stack.Item>
                <Stack.Item>
                  <Input
                    width="8rem"
                    value={tile}
                    onChange={(value) => setTile(value)}
                    onEnter={(value) => search({ tile: value })}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button tooltip="The tile you're on" onClick={() => act('here')}>
                    Mine
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button.Checkbox checked={inside} onClick={() => search({ inside: inside ? 0 : 1 })}>
                    Inside things too
                  </Button.Checkbox>
                </Stack.Item>
              </>
            )}
          </Stack>
        </Section>
        {counts.length > 1 && (
          <Section>
            {counts.map((count) => (
              <Button
                key={count.type}
                compact
                color="transparent"
                tooltip="Find this type"
                onClick={() => search({ mode: 'type', query: count.type })}
              >
                {count.type} <b>{count.count}</b>
              </Button>
            ))}
          </Section>
        )}
        <Section
          title={
            !searched
              ? 'Pick what to look for and where, then Find'
              : matched === 0
                ? 'Nothing found'
                : `${matched} found${matched > rows.length ? `, the first ${rows.length} shown` : ''}`
          }
          buttons={searched && <Box color="label">in {took} s</Box>}
        >
          {searched && matched === 0 && <NoticeBox>Nothing matches.</NoticeBox>}
          <Table>
            {rows.map((row) => (
              <Table.Row key={row.uid} className="candystripe">
                <Table.Cell py={0.5}>
                  <Box bold inline>
                    {row.name}
                  </Box>
                  {!!row.ckey && <Box inline color="label">{` (${row.ckey})`}</Box>}
                  {!!row.invisible && (
                    <Box inline ml={1} color="average">
                      unseen
                    </Box>
                  )}
                  {!!row.underfloor && (
                    <Box inline ml={1} color="average">
                      under floor
                    </Box>
                  )}
                  <Box color="label" fontSize="0.9em">
                    {row.type}
                    {!!row.where && ` · ${row.where}`}
                    {!!row.carrier && ` · carried by ${row.carrier}`}
                  </Box>
                </Table.Cell>
                <Table.Cell collapsing textAlign="right" verticalAlign="middle">
                  <Button compact onClick={() => act('vv', { uid: row.uid })}>
                    VV
                  </Button>
                  {!!row.where && row.where !== 'nullspace' && (
                    <Button compact onClick={() => act('jmp', { uid: row.uid })}>
                      JMP
                    </Button>
                  )}
                  {!!row.movable && (
                    <Button compact onClick={() => act('flw', { uid: row.uid })}>
                      FLW
                    </Button>
                  )}
                  {!!row.movable && (
                    <Button compact tooltip="Bring it to you" onClick={() => act('get', { uid: row.uid })}>
                      GET
                    </Button>
                  )}
                  <Button compact onClick={() => act('mark', { uid: row.uid })}>
                    MARK
                  </Button>
                  {!!row.where && row.where !== 'nullspace' && (
                    <Button compact tooltip="Everything on its tile" onClick={() => act('tile', { uid: row.uid })}>
                      TILE
                    </Button>
                  )}
                  <Button compact color="bad" onClick={() => act('del', { uid: row.uid })}>
                    DEL
                  </Button>
                </Table.Cell>
              </Table.Row>
            ))}
          </Table>
        </Section>
      </Window.Content>
    </Window>
  );
};
