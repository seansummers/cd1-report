#! /bin/bash -xe

pushd ..
mkdir dist

python -m pip install -r report/requirements.txt -t dist
rsync -a report dist/
python -m zipapp dist --compress -o report.pyz -p '/usr/bin/python3' -m report.app:main
rm -rf dist

popd

