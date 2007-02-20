#!/usr/bin/perl -0777 -pl


s!\&!\&amp;!g;
s!"!&quot;!g;
s!<!&lt;!g;
s!>!&gt;!g;
s!\e\[1;35m(.*?)\e\[0m!<span style="color: blue">$1</span>!sg;
s!\e\[1;31m(.*?)\e\[0m!<span style="color: red">$1</span>!sg;
#s!\n!<br/>\n!g;
s!\r\n!\n!g;
s!.+\r!!g;
s|^|<html><head><title>title</title></head><body><font size="6"><pre>|;
s|\z|</pre></font></body></html>\n|;
