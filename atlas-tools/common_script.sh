# proxy_sql.log
1. 过滤执行时间大于64.0 ms的查询
grep "Query" proxy_sql.log |awk '{a=index($14,"(");b=substr($14,0,a-1);if((b+0) > 64.0){print }}'|less

2. 统计执行时间的区间
(, 1ms] (1ms, 2ms] (2ms, 4ms] (4ms, 8ms] (8ms, 16ms] (16ms, 32ms] (32ms, 64ms] (64ms, 128ms] (128ms, ) total   大于64ms占比
cat proxy_sql.log|awk 'BEGIN {c1=0;c2=0;c4=0;c8=0;c16=0;c32=0;c64=0;c128=0;c=0}{split($14, latency, "("); if(latency[1] <= 1) {c1=c1+1;} if(latency[1]>1 && latency[1]<=2) {c2++;} if(latency[1]>2 && latency[1]<=4) {c4++;} if(latency[1]>4 && latency[1]<=8) {c8++;} if(latency[1]>8 && latency[1]<=16) {c16++;}  if(latency[1]>16 && latency[1]<=32) {c32++;} if(latency[1]>32 && latency[1]<=64) {c64++;} if(latency[1]>64 && latency[1]<=128) {c128++;} if(latency[1]>128) {c++;}} END{print c1, c2, c4, c8, c16, c32, c64, c128, c, (c1+c2+c4+c8+c16+c32+c64+c128+c), (c128+c)/(c1+c2+c4+c8+c16+c32+c64+c128+c)}'|less

# proxy_admin.log
1. 统计work thread 的负载
grep "event_thread" proxy_admin.log|awk 'BEGIN{a1;a2;a3;a4;a5;a6;a7;a8;a9;a10;a11;a12;a13;a14;a15;a16;}{a=index($4, "(");b=index($4, ")");c=substr($4, a+1, b-a-1);d=c+0;if(d == 0){a1++;};if(d == 1){a2++;};if(d == 2){a3++;};if(d == 3){a4++;};if(d == 4){a5++;};if(d == 5){a6++;};if(d == 6){a7++;};if(d == 7){a8++;};if(d == 8){a9++};if(d == 9){a10++;};if(d == 10){a11++;};if(d == 11){a12++;};if(d == 12){a13++;};if(d == 13){a14++;};if(d == 14){a15++;};if(d == 15){a16++;}}END{print a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16}'
