import { useEffect, useState } from 'react';
import {
  Box,
  Button,
  Dropdown,
  Input,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
  Tabs,
  TextArea,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Ban = {
  ids: number[];
  bantime: string;
  bantype: string;
  kind: string;
  perma: boolean;
  reason: string;
  roles: string[];
  duration: number;
  expires: string;
  ckey: string;
  admin: string;
  lifted_by: string | null;
  lifted_at: string | null;
  status: string;
  minutes_left: number;
  ip: string;
  cid: string;
  edits: string | null;
};

type Note = {
  id: number;
  text: string;
  time: string;
  admin: string;
  editor?: string;
  public: boolean;
  automated?: boolean;
};

type Watch = {
  reason: string;
  admin: string;
  time: string;
  editor?: string;
};

type PlayerRecord = {
  ckey: string;
  found: boolean;
  firstseen?: string;
  lastseen?: string;
  last_ip?: string;
  last_cid?: string;
  ips: string[];
  cids: string[];
  alts: { ckey: string; same_ip: boolean; same_cid: boolean }[];
  bans: Ban[];
  notes: Note[];
  watch?: Watch;
};

type Player = {
  ckey: string;
  name: string;
  online: boolean;
};

type RoleGroup = {
  name: string;
  roles: string[];
};

type Data = {
  tab: string;
  notice: string | null;
  notice_good: boolean;
  players: Player[];
  target_ckey: string;
  target_ip: string;
  target_cid: string;
  match_ip: boolean;
  match_cid: boolean;
  length_amount: number;
  length_unit: string;
  ends: string;
  kind: string;
  picked_roles: string[];
  reason: string;
  record: PlayerRecord | null;
  search_text: string;
  search_ckey: string;
  search_admin: string;
  search_status: string;
  search_kind: string;
  search_results: Ban[];
  searched: boolean;
  notes_ckey: string;
  notes: Note[];
  watch: Watch | null;
  groups: RoleGroup[];
};

const PRESETS: [string, number, string][] = [
  ['1h', 1, 'hours'],
  ['1d', 1, 'days'],
  ['3d', 3, 'days'],
  ['1w', 1, 'weeks'],
  ['1mo', 1, 'months'],
];

const UNITS = ['minutes', 'hours', 'days', 'weeks', 'months'];

/** "2d 3h left" from minutes */
const timeLeft = (minutes: number) => {
  if (minutes < 60) {
    return `${Math.max(minutes, 0)}m`;
  }
  const days = Math.floor(minutes / 1440);
  const hours = Math.floor((minutes % 1440) / 60);
  return days ? `${days}d${hours ? ` ${hours}h` : ''}` : `${hours}h`;
};

const statusText = (ban: Ban) => {
  if (ban.status === 'lifted') {
    return `lifted by ${ban.lifted_by}`;
  }
  if (ban.perma) {
    return ban.status === 'active' ? 'permanent' : 'expired';
  }
  return ban.status === 'active' ? `${timeLeft(ban.minutes_left)} left` : `ended ${ban.expires}`;
};

const statusColor = (ban: Ban) => (ban.status === 'active' ? 'bad' : ban.status === 'lifted' ? 'good' : 'label');

const kindText = (ban: Ban) =>
  ban.kind === 'roles' ? ban.roles.join(', ') : ban.kind === 'admin' ? 'Admin ban' : 'Server';

export const BanWindow = (props) => {
  const { act, data } = useBackend<Data>();
  const { tab, notice, notice_good } = data;
  return (
    <Window width={1080} height={720} title="Bans">
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Tabs>
              <Tabs.Tab icon="gavel" selected={tab === 'new'} onClick={() => act('tab', { tab: 'new' })}>
                New ban
              </Tabs.Tab>
              <Tabs.Tab icon="list" selected={tab === 'bans'} onClick={() => act('tab', { tab: 'bans' })}>
                Bans
              </Tabs.Tab>
              <Tabs.Tab icon="sticky-note" selected={tab === 'notes'} onClick={() => act('tab', { tab: 'notes' })}>
                Notes
              </Tabs.Tab>
            </Tabs>
          </Stack.Item>
          {!!notice && (
            <Stack.Item>
              {notice_good ? <NoticeBox success>{notice}</NoticeBox> : <NoticeBox danger>{notice}</NoticeBox>}
            </Stack.Item>
          )}
          <Stack.Item grow>
            {tab === 'new' && <NewBan />}
            {tab === 'bans' && <BanList />}
            {tab === 'notes' && <Notes />}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const NewBan = (props) => {
  const { act, data } = useBackend<Data>();
  const { target_ckey, match_ip, match_cid, length_amount, length_unit, ends, kind, picked_roles, record, groups } =
    data;
  const [ckey, setCkey] = useState(target_ckey);
  const [ip, setIp] = useState(data.target_ip);
  const [cid, setCid] = useState(data.target_cid);
  const [amount, setAmount] = useState(String(length_amount));
  const [reason, setReason] = useState(data.reason);
  const [showPlayers, setShowPlayers] = useState(false);
  useEffect(() => setCkey(target_ckey), [target_ckey]);
  useEffect(() => setIp(data.target_ip), [data.target_ip]);
  useEffect(() => setCid(data.target_cid), [data.target_cid]);
  useEffect(() => setAmount(String(length_amount)), [length_amount]);
  useEffect(() => setReason(data.reason), [data.reason]);

  // The roles they're banned from now, with the ban that does it
  const activeRoleBans: Record<string, Ban> = {};
  for (const ban of record?.bans || []) {
    if (ban.status === 'active' && ban.kind === 'roles') {
      for (const role of ban.roles) {
        activeRoleBans[role] = ban;
      }
    }
  }
  const perma = length_unit === 'perma';
  const what =
    kind === 'roles' ? `from ${picked_roles.length} role${picked_roles.length === 1 ? '' : 's'}` : 'from the server';
  const summary = target_ckey
    ? `Ban ${target_ckey} ${what} ${perma ? 'permanently' : `for ${length_amount} ${length_unit}`}.`
    : 'Pick a player.';

  return (
    <Stack fill>
      <Stack.Item grow basis="58%">
        <Section fill scrollable>
          <LabeledList>
            <LabeledList.Item label="Player">
              <Stack>
                <Stack.Item grow>
                  <Input
                    fluid
                    value={ckey}
                    placeholder="A ckey"
                    onChange={(value) => setCkey(value)}
                    onEnter={(value) => act('set_target', { ckey: value })}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button icon="users" selected={showPlayers} onClick={() => setShowPlayers(!showPlayers)}>
                    Players
                  </Button>
                </Stack.Item>
              </Stack>
              {showPlayers && (
                <Box mt={0.5}>
                  {data.players.map((player) => (
                    <Button
                      key={player.ckey}
                      color={player.online ? 'default' : 'transparent'}
                      tooltip={player.online ? 'Online' : 'Left this round'}
                      onClick={() => {
                        setShowPlayers(false);
                        act('set_target', { ckey: player.ckey });
                      }}
                    >
                      {player.ckey}
                      <Box inline color="label" ml={0.5}>
                        {player.name}
                      </Box>
                    </Button>
                  ))}
                </Box>
              )}
            </LabeledList.Item>
            <LabeledList.Item label="Match">
              <Stack align="center">
                <Stack.Item>
                  <Button.Checkbox checked={match_ip} onClick={() => act('set_form', { match_ip: match_ip ? 0 : 1 })}>
                    IP
                  </Button.Checkbox>
                </Stack.Item>
                <Stack.Item>
                  <Input
                    width="9rem"
                    value={ip}
                    onChange={(value) => setIp(value)}
                    onBlur={(value) => act('set_form', { ip: value })}
                    onEnter={(value) => act('set_form', { ip: value })}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button.Checkbox
                    checked={match_cid}
                    onClick={() => act('set_form', { match_cid: match_cid ? 0 : 1 })}
                  >
                    Computer ID
                  </Button.Checkbox>
                </Stack.Item>
                <Stack.Item>
                  <Input
                    width="9rem"
                    value={cid}
                    onChange={(value) => setCid(value)}
                    onBlur={(value) => act('set_form', { cid: value })}
                    onEnter={(value) => act('set_form', { cid: value })}
                  />
                </Stack.Item>
              </Stack>
            </LabeledList.Item>
            <LabeledList.Item label="Length">
              <Stack align="center">
                {PRESETS.map(([label, presetAmount, unit]) => (
                  <Stack.Item key={label}>
                    <Button
                      selected={!perma && length_amount === presetAmount && length_unit === unit}
                      onClick={() => act('set_form', { amount: presetAmount, unit: unit })}
                    >
                      {label}
                    </Button>
                  </Stack.Item>
                ))}
                <Stack.Item>
                  <Button selected={perma} onClick={() => act('set_form', { unit: 'perma' })}>
                    Perm
                  </Button>
                </Stack.Item>
                {!perma && (
                  <>
                    <Stack.Item>
                      <Input
                        width="4rem"
                        value={amount}
                        onChange={(value) => setAmount(value)}
                        onBlur={(value) => act('set_form', { amount: value })}
                        onEnter={(value) => act('set_form', { amount: value })}
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <Dropdown
                        width="7rem"
                        options={UNITS}
                        selected={length_unit}
                        onSelected={(value) => act('set_form', { unit: value })}
                      />
                    </Stack.Item>
                  </>
                )}
              </Stack>
              <Box color="label" mt={0.5}>
                {ends}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Ban from">
              <Button icon="server" selected={kind === 'server'} onClick={() => act('set_form', { kind: 'server' })}>
                The server
              </Button>
              <Button icon="user-tag" selected={kind === 'roles'} onClick={() => act('set_form', { kind: 'roles' })}>
                Roles
              </Button>
              <Button
                icon="user-shield"
                selected={kind === 'admin'}
                tooltip="An admin ban: one per admin at a time, and it's announced"
                onClick={() => act('set_form', { kind: 'admin' })}
              >
                Admin ban
              </Button>
            </LabeledList.Item>
          </LabeledList>
          {kind === 'roles' && (
            <Box mt={1}>
              {groups.map((group) => {
                const allPicked = group.roles.every((role) => picked_roles.includes(role) || activeRoleBans[role]);
                return (
                  <Box key={group.name} mb={0.5}>
                    <Button
                      compact
                      color="transparent"
                      icon={allPicked ? 'check-square' : 'square'}
                      onClick={() =>
                        act('toggle_roles', {
                          roles: group.roles.filter((role) => !activeRoleBans[role]),
                          on: allPicked ? 0 : 1,
                        })
                      }
                    >
                      <b>{group.name}</b>
                    </Button>
                    <Box>
                      {group.roles.map((role) => {
                        const ban = activeRoleBans[role];
                        if (ban) {
                          return (
                            <Button.Confirm
                              key={role}
                              compact
                              color="bad"
                              tooltip={`Banned: ${ban.reason}. Click twice to lift.`}
                              confirmContent={`Lift ${role}?`}
                              onClick={() => act('lift', { ids: ban.ids })}
                            >
                              {role}{' '}
                              <Box inline opacity={0.7}>
                                {ban.perma ? 'perm' : timeLeft(ban.minutes_left)}
                              </Box>
                            </Button.Confirm>
                          );
                        }
                        const picked = picked_roles.includes(role);
                        return (
                          <Button
                            key={role}
                            compact
                            selected={picked}
                            onClick={() => act('toggle_roles', { roles: [role], on: picked ? 0 : 1 })}
                          >
                            {role}
                          </Button>
                        );
                      })}
                    </Box>
                  </Box>
                );
              })}
            </Box>
          )}
          <Box mt={1} color="label">
            Reason
          </Box>
          <TextArea
            fluid
            height="5rem"
            value={reason}
            onChange={(value) => setReason(value)}
            onBlur={(value) => act('set_form', { reason: value })}
          />
          <Stack mt={1} align="center">
            <Stack.Item grow color="label">
              {summary}
            </Stack.Item>
            <Stack.Item>
              <Button.Confirm
                icon="gavel"
                color="bad"
                disabled={!target_ckey}
                confirmContent="Click again to ban"
                onClick={() => act('ban', { reason: reason })}
              >
                Ban
              </Button.Confirm>
            </Stack.Item>
          </Stack>
        </Section>
      </Stack.Item>
      <Stack.Item grow basis="42%">
        <PlayerRecordPanel />
      </Stack.Item>
    </Stack>
  );
};

const PlayerRecordPanel = (props) => {
  const { act, data } = useBackend<Data>();
  const { record } = data;
  if (!record) {
    return (
      <Section fill title="Their record">
        <Box color="label">Pick a player to see their bans, notes and alts.</Box>
      </Section>
    );
  }
  const active = record.bans.filter((ban) => ban.status === 'active');
  return (
    <Section fill scrollable title={record.ckey}>
      {!record.found && <NoticeBox>This ckey isn't in the player database.</NoticeBox>}
      {record.found && (
        <LabeledList>
          <LabeledList.Item label="Seen">
            {record.firstseen} to {record.lastseen}
          </LabeledList.Item>
          <LabeledList.Item label="IPs">{record.ips.join(', ') || record.last_ip}</LabeledList.Item>
          <LabeledList.Item label="Computers">{record.cids.join(', ') || record.last_cid}</LabeledList.Item>
          {record.alts.length > 0 && (
            <LabeledList.Item label="Same IP or PC">
              {record.alts.map((alt) => (
                <Button
                  key={alt.ckey}
                  compact
                  color={alt.same_cid ? 'average' : 'default'}
                  tooltip={alt.same_cid ? 'Same computer ID' : 'Same IP'}
                  onClick={() => act('set_target', { ckey: alt.ckey })}
                >
                  {alt.ckey}
                </Button>
              ))}
            </LabeledList.Item>
          )}
        </LabeledList>
      )}
      <Box mt={1} bold>
        Bans{' '}
        <Box inline color="label">
          {active.length} active, {record.bans.length} in all
        </Box>
      </Box>
      {record.bans.map((ban) => (
        <BanRow key={ban.ids.join(',')} ban={ban} showCkey={false} />
      ))}
      <Box mt={1} bold>
        Notes{' '}
        <Box inline color="label">
          the latest {record.notes.length}
        </Box>
      </Box>
      {record.notes.map((note) => (
        <Box key={note.id} mb={0.5}>
          <Box color="label" fontSize="0.9em">
            {note.time} by {note.admin}
            {note.public ? ' (public)' : ''}
          </Box>
          {note.text}
        </Box>
      ))}
      {!!record.watch && (
        <Box mt={1}>
          <Box bold color="average">
            Watchlist
          </Box>
          {record.watch.reason}
          <Box color="label" fontSize="0.9em">
            by {record.watch.admin}, {record.watch.time}
          </Box>
        </Box>
      )}
    </Section>
  );
};

const BanRow = (props: { ban: Ban; showCkey: boolean }) => {
  const { act } = useBackend<Data>();
  const { ban, showCkey } = props;
  const [editing, setEditing] = useState(false);
  const [reason, setReason] = useState(ban.reason);
  const [minutes, setMinutes] = useState(String(ban.duration));
  return (
    <Box mb={1} pl={1} style={{ borderLeft: `3px solid ${ban.status === 'active' ? '#bd2020' : '#555'}` }}>
      <Stack align="center">
        <Stack.Item grow>
          {showCkey && <b>{ban.ckey} </b>}
          <b>{kindText(ban)}</b>
          <Box inline color="label" ml={0.5}>
            · {ban.bantime} · {ban.admin}
          </Box>
        </Stack.Item>
        <Stack.Item>
          <Box inline color={statusColor(ban)}>
            {statusText(ban)}
          </Box>
        </Stack.Item>
        {ban.status === 'active' && (
          <>
            <Stack.Item>
              <Button compact icon="pen" selected={editing} onClick={() => setEditing(!editing)}>
                Edit
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button.Confirm
                compact
                icon="unlock"
                confirmContent="Lift?"
                onClick={() => act('lift', { ids: ban.ids })}
              >
                Lift
              </Button.Confirm>
            </Stack.Item>
          </>
        )}
      </Stack>
      <Box>{ban.reason}</Box>
      {editing && (
        <Box mt={0.5}>
          <TextArea fluid height="3rem" value={reason} onChange={(value) => setReason(value)} />
          <Stack mt={0.5} align="center">
            {!ban.perma && (
              <>
                <Stack.Item color="label">Minutes from when it was made</Stack.Item>
                <Stack.Item>
                  <Input width="6rem" value={minutes} onChange={(value) => setMinutes(value)} />
                </Stack.Item>
              </>
            )}
            <Stack.Item grow />
            <Stack.Item>
              <Button
                icon="save"
                onClick={() => {
                  setEditing(false);
                  act('edit', {
                    ids: ban.ids,
                    reason: reason !== ban.reason ? reason : '',
                    minutes: !ban.perma && minutes !== String(ban.duration) ? minutes : '',
                  });
                }}
              >
                Save
              </Button>
            </Stack.Item>
          </Stack>
        </Box>
      )}
    </Box>
  );
};

const BanList = (props) => {
  const { act, data } = useBackend<Data>();
  const { search_status, search_kind, search_results, searched } = data;
  const [text, setText] = useState(data.search_text);
  const [ckey, setCkey] = useState(data.search_ckey);
  const [admin, setAdmin] = useState(data.search_admin);
  const search = (change = {}) =>
    act('search', { text, ckey, admin, status: search_status, kind: search_kind, ...change });
  return (
    <Section fill scrollable>
      <Stack align="center" mb={1}>
        <Stack.Item grow>
          <Input
            fluid
            value={text}
            placeholder="Words in the reason, a role, an IP or a computer ID"
            onChange={(value) => setText(value)}
            onEnter={(value) => search({ text: value })}
          />
        </Stack.Item>
        <Stack.Item>
          <Input
            width="9rem"
            value={ckey}
            placeholder="Player"
            onChange={(value) => setCkey(value)}
            onEnter={(value) => search({ ckey: value })}
          />
        </Stack.Item>
        <Stack.Item>
          <Input
            width="9rem"
            value={admin}
            placeholder="Banned by"
            onChange={(value) => setAdmin(value)}
            onEnter={(value) => search({ admin: value })}
          />
        </Stack.Item>
        <Stack.Item>
          <Button icon="search" onClick={() => search()}>
            Search
          </Button>
        </Stack.Item>
      </Stack>
      <Stack mb={1}>
        {['active', 'expired', 'lifted', 'all'].map((status) => (
          <Stack.Item key={status}>
            <Button selected={search_status === status} onClick={() => search({ status })}>
              {status[0].toUpperCase() + status.slice(1)}
            </Button>
          </Stack.Item>
        ))}
        <Stack.Item ml={2}>
          {['all', 'server', 'roles'].map((kind) => (
            <Button key={kind} selected={search_kind === kind} onClick={() => search({ kind })}>
              {kind === 'all' ? 'Any kind' : kind === 'server' ? 'Server' : 'Roles'}
            </Button>
          ))}
        </Stack.Item>
        <Stack.Item grow textAlign="right" color="label">
          {searched && `${search_results.length} ban${search_results.length === 1 ? '' : 's'}`}
          {search_status === 'active' && ', ending soonest first'}
        </Stack.Item>
      </Stack>
      {search_results.map((ban) => (
        <BanRow key={ban.ids.join(',')} ban={ban} showCkey />
      ))}
    </Section>
  );
};

const Notes = (props) => {
  const { act, data } = useBackend<Data>();
  const { notes_ckey, notes, watch } = data;
  const [ckey, setCkey] = useState(notes_ckey);
  const [newNote, setNewNote] = useState('');
  const [isPublic, setPublic] = useState(false);
  const [watchText, setWatchText] = useState(watch?.reason || '');
  const [editing, setEditing] = useState(0);
  const [editText, setEditText] = useState('');
  useEffect(() => setCkey(notes_ckey), [notes_ckey]);
  useEffect(() => setWatchText(watch?.reason || ''), [watch?.reason]);
  return (
    <Section fill scrollable>
      <Stack align="center" mb={1}>
        <Stack.Item>Player</Stack.Item>
        <Stack.Item grow>
          <Input
            fluid
            value={ckey}
            placeholder="A ckey"
            onChange={(value) => setCkey(value)}
            onEnter={(value) => act('notes_for', { ckey: value })}
          />
        </Stack.Item>
        <Stack.Item>
          <Button icon="search" onClick={() => act('notes_for', { ckey })}>
            Show
          </Button>
        </Stack.Item>
      </Stack>
      {!!notes_ckey && (
        <>
          <Section title="Watchlist">
            <TextArea
              fluid
              height="3rem"
              value={watchText}
              placeholder="Not on the watchlist. Write a reason to add them."
              onChange={(value) => setWatchText(value)}
            />
            <Box mt={0.5} textAlign="right">
              {!!watch && (
                <Box inline color="label" mr={1}>
                  added by {watch.admin}, {watch.time}
                </Box>
              )}
              <Button icon="eye" disabled={!watchText} onClick={() => act('watch_set', { text: watchText })}>
                {watch ? 'Save reason' : 'Add to the watchlist'}
              </Button>
              {!!watch && (
                <Button.Confirm icon="eye-slash" confirmContent="Remove?" onClick={() => act('watch_remove')}>
                  Remove
                </Button.Confirm>
              )}
            </Box>
          </Section>
          <Section title={`Notes (${notes.length})`}>
            <TextArea
              fluid
              height="3rem"
              value={newNote}
              placeholder="A new note"
              onChange={(value) => setNewNote(value)}
            />
            <Box mt={0.5} mb={1} textAlign="right">
              <Button.Checkbox checked={isPublic} onClick={() => setPublic(!isPublic)}>
                Public
              </Button.Checkbox>
              <Button
                icon="plus"
                disabled={!newNote}
                onClick={() => {
                  act('add_note', { text: newNote, public: isPublic ? 1 : 0 });
                  setNewNote('');
                }}
              >
                Add note
              </Button>
            </Box>
            {notes.map((note) => (
              <Box key={note.id} mb={1} pl={1} style={{ borderLeft: '3px solid #555' }}>
                <Stack align="center">
                  <Stack.Item grow color="label">
                    {note.time} by {note.admin}
                    {note.editor ? `, edited by ${note.editor}` : ''}
                    {note.automated ? ' (automatic)' : ''}
                  </Stack.Item>
                  {!note.automated && (
                    <>
                      <Stack.Item>
                        <Button.Confirm
                          compact
                          selected={note.public}
                          confirmContent={note.public ? 'Make private?' : 'Make public?'}
                          onClick={() => act('note_public', { id: note.id })}
                        >
                          {note.public ? 'Public' : 'Private'}
                        </Button.Confirm>
                      </Stack.Item>
                      <Stack.Item>
                        <Button
                          compact
                          icon="pen"
                          selected={editing === note.id}
                          onClick={() => {
                            setEditing(editing === note.id ? 0 : note.id);
                            setEditText(note.text);
                          }}
                        >
                          Edit
                        </Button>
                      </Stack.Item>
                    </>
                  )}
                  <Stack.Item>
                    <Button.Confirm
                      compact
                      icon="trash"
                      color="bad"
                      confirmContent="Delete?"
                      onClick={() => act('delete_note', { id: note.id })}
                    />
                  </Stack.Item>
                </Stack>
                {editing === note.id ? (
                  <Box mt={0.5}>
                    <TextArea fluid height="3rem" value={editText} onChange={(value) => setEditText(value)} />
                    <Box mt={0.5} textAlign="right">
                      <Button
                        icon="save"
                        onClick={() => {
                          setEditing(0);
                          act('edit_note', { id: note.id, text: editText });
                        }}
                      >
                        Save
                      </Button>
                    </Box>
                  </Box>
                ) : (
                  <Box>{note.text}</Box>
                )}
              </Box>
            ))}
          </Section>
        </>
      )}
    </Section>
  );
};
