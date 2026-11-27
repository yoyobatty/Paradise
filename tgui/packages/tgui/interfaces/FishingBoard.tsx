import { NoticeBox, Section, Table } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type BoardData = {
  records: FishingRecord[];
};

type FishingRecord = {
  fish: string;
  angler: string;
  length: number;
  spot: string;
  time: string;
};

export const FishingBoard = (props) => {
  const { data } = useBackend<BoardData>();
  // Biggest fish at the top
  const records = [...data.records].sort((a, b) => b.length - a.length);
  return (
    <Window width={520} height={400}>
      <Window.Content scrollable>
        <Section fill title="Biggest catches this shift">
          {records.length === 0 ? (
            <NoticeBox>Nobody has caught anything yet. The fish are getting cocky.</NoticeBox>
          ) : (
            <Table>
              <Table.Row header>
                <Table.Cell>Fish</Table.Cell>
                <Table.Cell>Length</Table.Cell>
                <Table.Cell>Caught by</Table.Cell>
                <Table.Cell>Caught in</Table.Cell>
                <Table.Cell>Time</Table.Cell>
              </Table.Row>
              {records.map((record) => (
                <Table.Row key={record.fish} className="candystripe">
                  <Table.Cell bold style={{ textTransform: 'capitalize' }}>
                    {record.fish}
                  </Table.Cell>
                  <Table.Cell>{record.length} cm</Table.Cell>
                  <Table.Cell>{record.angler}</Table.Cell>
                  <Table.Cell>{record.spot}</Table.Cell>
                  <Table.Cell>{record.time}</Table.Cell>
                </Table.Row>
              ))}
            </Table>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
