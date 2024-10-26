import json
import asyncio
import signal
import time
from collections import defaultdict
from types import FrameType
from typing import Any

from atproto import (
    CAR,
    AsyncFirehoseSubscribeReposClient,
    AtUri,
    firehose_models,
    models,
    parse_subscribe_repos_message,
)

_INTERESTED_RECORDS = {
    models.ids.AppBskyFeedLike: models.AppBskyFeedLike,
    models.ids.AppBskyFeedPost: models.AppBskyFeedPost,
    models.ids.AppBskyGraphFollow: models.AppBskyGraphFollow,
}

fundraiser_uris = [
    'gofundme.com',
    'gofund.me',
    'ko-fi.com'
    'buymeacoffee.com',
    'venmo.com'
    'cash.app',
    'cash.me',
    'paypal.me',
    'paypal.com',
    'gogetfunding.com'
]

propaganda_uris = [
    'thegrayzone.com',
    'grayzoneproject.com',
    'mintpressnews.com',
    '21stcenturywire.com',
    'www.globalresearch.ca',
    'globalresearch.ca',
    'journal-neo.su',
    'theWallWillFall.org',
    'beeley.substack.com',
    '.rt.com',
    'sputniknews.com',
    'zerohedge.com',
    'theduran.com',
    '.unz.com',
    'presstv.ir',
    'www.presstv.ir',
    'x.com/Partisangirl',
]


def _get_ops_by_type(commit: models.ComAtprotoSyncSubscribeRepos.Commit) -> defaultdict:
    operation_by_type = defaultdict(lambda: {'created': [], 'deleted': []})

    car = CAR.from_bytes(commit.blocks)
    for op in commit.ops:
        if op.action == 'update':
            # not supported yet
            continue

        uri = AtUri.from_str(f'at://{commit.repo}/{op.path}')

        if op.action == 'create':
            if not op.cid:
                continue

            create_info = {'uri': str(uri), 'cid': str(op.cid), 'author': commit.repo}

            record_raw_data = car.blocks.get(op.cid)
            if not record_raw_data:
                continue

            record = models.get_or_create(record_raw_data, strict=False)
            record_type = _INTERESTED_RECORDS.get(uri.collection)
            if record_type and models.is_record_type(record, record_type):
                operation_by_type[uri.collection]['created'].append({'record': record, **create_info})

        if op.action == 'delete':
            operation_by_type[uri.collection]['deleted'].append({'uri': str(uri)})

    return operation_by_type


def measure_events_per_second(func: callable) -> callable:
    def wrapper(*args) -> Any:
        wrapper.calls += 1
        cur_time = time.time()

        if cur_time - wrapper.start_time >= 1:
            print(f'NETWORK LOAD: {wrapper.calls} events/second')
            wrapper.start_time = cur_time
            wrapper.calls = 0

        return func(*args)

    wrapper.calls = 0
    wrapper.start_time = time.time()

    return wrapper


async def signal_handler(_: int, __: FrameType) -> None:
    print('Keyboard interrupt received. Stopping...')

    # Stop receiving new messages
    await client.stop()


def check_facets(record) -> tuple[bool, bool, bool]:
    fundraiser = False
    propaganda = False
    sports_betting = False
    if record.facets is not None:
        # TODO: Turn these into list comprehensions. Speed good. Go fast.
        # Loop through each facet
        for facet in record.facets:
            for feat in facet.features:
                if feat.py_type == 'app.bsky.richtext.facet#link':
                    print(feat.uri)
                    # check if any of the fundraiser uris are in the link
                    for fundraiser_uri in fundraiser_uris:
                        # Look for feat.uri as a substring of fundraiser_uri
                        if fundraiser_uri in feat.uri.lower():
                            fundraiser = True
                    for propaganda_uri in propaganda_uris:
                        # Look for feat.uri as a substring of propaganda_uri
                        if propaganda_uri in feat.uri.lower():
                            propaganda = True

    return fundraiser, propaganda, sports_betting


def label_post(record, label: str) -> None:
    print(f'Labeling post {record.cid} as {label}')


async def main(firehose_client: AsyncFirehoseSubscribeReposClient) -> None:
    @measure_events_per_second
    async def on_message_handler(message: firehose_models.MessageFrame) -> None:
        commit = parse_subscribe_repos_message(message)
        if not isinstance(commit, models.ComAtprotoSyncSubscribeRepos.Commit):
            return

        if commit.seq % 20 == 0:
            firehose_client.update_params(models.ComAtprotoSyncSubscribeRepos.Params(cursor=commit.seq))

        if not commit.blocks:
            return

        ops = _get_ops_by_type(commit)
        for created_post in ops[models.ids.AppBskyFeedPost]['created']:
            author = created_post['author']
            record = created_post['record']
            fundraiser, propaganda, sports_betting = check_facets(record)
            if fundraiser:
                # TODO: Label as such
                pass
            if propaganda:
                # TODO: Label as such
                pass
            if sports_betting:
                # TODO: Label as such
                pass


    await client.start(on_message_handler)


if __name__ == '__main__':
    signal.signal(signal.SIGINT, lambda _, __: asyncio.create_task(signal_handler(_, __)))

    start_cursor = None

    params = None
    if start_cursor is not None:
        params = models.ComAtprotoSyncSubscribeRepos.Params(cursor=start_cursor)

    client = AsyncFirehoseSubscribeReposClient(params)

    # use run() for a higher Python version
    asyncio.get_event_loop().run_until_complete(main(client))
