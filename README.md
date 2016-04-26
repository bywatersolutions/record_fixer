# record_fixer
A tool to remove badly encoded characters from MARC records in Koha, or report which bibs have bad MARC data.

## Usage
`record_fixer.pl`

The script takes no arguments. It shows a rudamentary progress indicator, then writes its output to `/tmp/$ENV{USER}.record_fixer.yaml`. The Yaml file contains the biblionumbers of 'good', 'bad' and 'edited' records.
