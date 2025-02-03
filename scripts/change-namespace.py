#!/usr/bin/env python3
import sys

import argparse
import yaml
from io import StringIO


def yaml_dumps(obj):
    string_stream = StringIO()
    yaml.dump(obj, string_stream)
    output_str = string_stream.getvalue()
    string_stream.close()
    return output_str

def yaml_dump_alls(obj):
    string_stream = StringIO()
    yaml.dump_all(obj, string_stream)
    output_str = string_stream.getvalue()
    string_stream.close()
    return output_str

def parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument('-n', '--namespace', required=True)

    return parser.parse_args()

def main(args: argparse.Namespace):
    resources = list(filter(None, yaml.safe_load_all(sys.stdin)))

    for resource in resources:
        resource["metadata"]["namespace"] = args.namespace

    yaml.dump_all(resources, sys.stdout)

main(parse_args())
