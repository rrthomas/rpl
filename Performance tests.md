# rpl performance tests

many-a.txt: a file of 20M a's:

```
python3 -c "with open('many-a.orig.txt', 'wb') as f: f.write(b'a' * (20 * 1000 * 1000))"
```

Perf setup:

```
echo -1 > /proc/sys/kernel/perf_event_paranoid
echo 0 > /proc/sys/kernel/kptr_restrict
```

Running perf:

```
cp many-a.{orig.,}txt; perf record --event=instructions -- ./rpl '(?<!a)a' b many-a.txt
perf report --stdio | grep "Event count"
```


## Results

Testing on MacBook Pro with i5-4288U.

“w/encoding” columns have `--encoding=iso-8859-1` added.

Sed tests done with `sed -i s/a/b/g many-a.txt` etc.


Command                     Python   Vala   Python w/encoding  Vala w/encoding  sed    Notes
-------                     ------   ----   -----------------  ---------------  -----  -----

rpl a b many-a.txt            130G    57G   130G                58G               21G
rpl a* b many-a.txt           1.4G   0.8G   1.1G               1.1G              0.9G
rpl a+ b many-a.txt           1.4G   0.7G   1.1G               1.1G              0.4G
rpl a*x b many-a.txt          2.1G   0.8G   1.8G               1.8G              0.3G
rpl (?<!a)a b many-a.txt       28G   1.4G    28G               2.4G              n/a   Python buggy: 1 match per buffer load
