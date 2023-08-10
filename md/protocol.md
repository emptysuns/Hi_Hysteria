### Introduction to each agreement

#### 1. UDP

It can be recognized as a Quic traffic and the best use.

After the script 0.2.5 version is no longer added by default, the `OBFS` option is added. Because the overhead of confusion is too large, the CPU performance will become a bottleneck of speed.

Moreover, the operator will not only speed the speed limit of the speed of speed. It has not been limited during the long test, so the support of `OBFS` is canceled.

#### 2, Faketcp

Hysteria V0.9.1 began to support FAKETCP, and camouled Hysteria's UDP transmission process as TCP. You can avoid the speed limit and blocking of UDP devices of operators and "more professional" IDC service providers.

At present, the FakeTCP mode client only supports the use of Android in the Linux system ROOT users. ** Windows cannot use ** (but it can be replaced by UDP2RAW camouflage TCP instead).

So my suggestion is:

** Do not turn on it when pursuing proxy performance **. When the current speed has been limited when the situation such as 128kb/s is very, very low, you confirm that it is restricted to the UDP before reinstalizing it. "slow down".

** Pursuing stability and can prepare for root permissions to use the environment **. You can open it to open FakeTCP.

#### 3, wechat-video

Voice and video calls disguised as WeChat may bypass a small number of domestic operators for UDP targeted speed limit? To be confirmed.
