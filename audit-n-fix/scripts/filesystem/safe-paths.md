# Safe Paths

> [!TIP]
>
> You may want to use a text viewer which displays null bytes (e.g. `less -R (path)`),
> as null bytes is what's used to delimitate each path from another
> (null bytes and forward slashes may not be used to name nodes)
> when viewing the log files from commands mentioned here.

## Nodes w/ Non-ascii

Use the below command to scan for nodes w/ non-ascii characters in their name:

```sh
find / -mindepth 1 ! -iregex '^[\x00-\x7F\n]+$' -xephem -print0 | tee "nodes-with-non-ascii.log"
```

You can find the results in the file `nodes-with-non-ascii.log` of your CWD.

## Nodes w/ Leading Hyphens

Use the below command to scan for nodes w/ leading hyphens in their name:

```sh
find / -mindepth 1 -name '-*' -xephem -print0 | tee "nodes-with-leading-hyphen.log"
```

You can find the results in `nodes-with-leading-hyphen.log` of your CWD.
