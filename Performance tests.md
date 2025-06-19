# rpl tests

many-a.txt: a file of 2 BEEELION a's.

rpl a b many-a.txt





## Results


Command                     Python   Vala   Notes
-------                     ------   ----   -----

rpl a b many-a.txt          1m38s    8m20s
rpl a* b many-a.tx             7s       7s  Python answer is wrong: 2 b's!
rpl a*x b many-a.txt          ??s      ??s
rpl a*x b some-a.txt         1.3s      XXX  Got bored, gave up