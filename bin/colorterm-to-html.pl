#!/usr/bin/perl -0777 -pl


s!\&!\&amp;!g;
s!"!&quot;!g;
s!<!&lt;!g;
s!>!&gt;!g;
s!\e\[1;3[45](?:;\d+)?m(.*?)\e\[0m!<span style="color: blue">$1</span>!sg;
s!\e\[1;31(?:;\d+)m(.*?)\e\[0m!<span style="color: red">$1</span>!sg;
#s!\n!<br/>\n!g;
s!\r\n!\n!g;
s!.+\r!!g;
