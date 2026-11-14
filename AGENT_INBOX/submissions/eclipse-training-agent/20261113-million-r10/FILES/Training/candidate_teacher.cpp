#include <array>
#include <vector>
#include <fstream>
#include <iostream>
#include <cmath>
#include <cstring>
using namespace std;
const int N=225,F=26;
vector<array<int,5>> windows;
vector<int> through[N];
int board[N];
bool valid(int r,int c){return r>=0&&r<15&&c>=0&&c<15;}
int drs[4]={1,0,1,1},dcs[4]={0,1,1,-1};
int forks(int side){
 int first[N]; fill(first,first+N,-1);bool marked[N]={};int count=0;
 for(auto &w:windows){int own=0,a=-1,b=-1;bool blocked=false;
  for(int i:w){if(board[i]==side)own++;else if(board[i]){blocked=true;break;}else if(a<0)a=i;else b=i;}
  if(blocked||own!=3||a<0||b<0)continue;
  if(first[a]<0)first[a]=b;else if(first[a]!=b&&!marked[a]){marked[a]=true;count++;}
  if(first[b]<0)first[b]=a;else if(first[b]!=a&&!marked[b]){marked[b]=true;count++;}
 }return count;
}
int immediate(int side){int n=0;bool seen[N]={};for(auto &w:windows){int own=0,a=-1;bool blocked=false;for(int i:w){if(board[i]==side)own++;else if(board[i]){blocked=true;break;}else a=i;}if(!blocked&&own==4&&a>=0&&!seen[a]){seen[a]=true;n++;}}return n;}
void feature(int index,float*x){
 fill(x,x+F,0);int r=index/15,c=index%15;
 for(int k:through[index]){auto&w=windows[k];int a=0,b=0;for(int i:w){a+=board[i]==1;b+=board[i]==2;}
  if(b==0&&a>=1&&a<=4)x[a-1]++;
  if(a==0&&b>=1&&b<=4)x[4+b-1]++;
 }
 int ownFour=0,oppFour=0;
 for(int d=0;d<4;d++){
  int own=1,opp=1,ownOpen=0,oppOpen=0;
  for(int sign:{-1,1}){
   int rr=r+sign*drs[d],cc=c+sign*dcs[d];
   while(valid(rr,cc)&&board[rr*15+cc]==1){own++;rr+=sign*drs[d];cc+=sign*dcs[d];}
   ownOpen+=valid(rr,cc)&&board[rr*15+cc]==0;
   rr=r+sign*drs[d];cc=c+sign*dcs[d];
   while(valid(rr,cc)&&board[rr*15+cc]==2){opp++;rr+=sign*drs[d];cc+=sign*dcs[d];}
   oppOpen+=valid(rr,cc)&&board[rr*15+cc]==0;
  }
  x[8]=max(x[8],float(own));x[9]=max(x[9],float(opp));
  if(own>=3&&ownOpen==2)x[10]++;
  if(opp>=3&&oppOpen==2)x[11]++;
  if(own>=4&&ownOpen>=1)x[12]++;
  if(opp>=4&&oppOpen>=1)x[13]++;
  if(own>=3&&ownOpen>=1)ownFour++;
  if(opp>=3&&oppOpen>=1)oppFour++;
  for(int sign:{-1,1})for(int dist=1;dist<=2;dist++){
   int rr=r+sign*dist*drs[d],cc=c+sign*dist*dcs[d];if(!valid(rr,cc))continue;
   if(board[rr*15+cc]==1)x[dist==1?14:16]++;
   if(board[rr*15+cc]==2)x[dist==1?15:17]++;
  }
 }
 x[18]=15-abs(r-7)-abs(c-7);x[19]=min(min(r,c),min(14-r,14-c));
 for(int i=0;i<N;i++)x[20]+=board[i]!=0;
 x[21]=ownFour;x[22]=oppFour;
 x[23]=x[2]*(x[2]-1)/2; x[24]=x[6]*(x[6]-1)/2;
 x[25]=1;
}
int main(int argc,char**argv){
 if(argc!=3){cerr<<"candidate_teacher boards.txt candidates.f32\n";return 2;}
 for(int d=0;d<4;d++)for(int r=0;r<15;r++)for(int c=0;c<15;c++)if(valid(r+4*drs[d],c+4*dcs[d])){
  array<int,5>w;for(int k=0;k<5;k++)w[k]=(r+k*drs[d])*15+c+k*dcs[d];int no=windows.size();windows.push_back(w);for(int i:w)through[i].push_back(no);
 }
 ifstream in(argv[1]);ofstream out(argv[2],ios::binary);string line;long rows=0;int id=0;
 while(getline(in,line)){
  if(line.size()!=225){cerr<<"bad board\n";return 3;}for(int i=0;i<N;i++)board[i]=line[i]-'0';
  int beforeFork=forks(2),ownImm=immediate(1),oppImm=immediate(2),ownFork=forks(1);
  bool nonforced=ownImm==0&&oppImm==0&&ownFork==0;
  for(int i=0;i<N;i++)if(!board[i]){
   float rec[F+8];feature(i,rec);board[i]=1;
   int risk=forks(2), ownAfter=forks(1),wins=immediate(1);
   // Independent rule-derived two-turn tactical utility. Exact opponent fork
   // count and own post-move fork multiplicity are LABELS, never model inputs.
   // Prioritize forcing moves; otherwise remove opponent's next fork and build
   // multiple future forcing continuations. These are counterfactual labels.
   float utility=0;
   utility+=wins>=2?140.f:(wins==1?65.f:0.f);
   utility+=25.f*min(4,ownAfter);
   utility-=65.f*min(5,risk);
   utility+=4.f*rec[2]+.8f*rec[1]+.10f*rec[0];
   utility+=3.5f*rec[6]+.6f*rec[5]+.08f*rec[4];
   utility+=2.f*rec[10]+2.5f*rec[11]+.02f*rec[18];
   if(rec[3]>0)utility=500.f;
   rec[F]=utility;rec[F+1]=id;rec[F+2]=i;rec[F+3]=risk;rec[F+4]=wins;rec[F+5]=ownAfter;rec[F+6]=nonforced;rec[F+7]=beforeFork;
   out.write(reinterpret_cast<char*>(rec),sizeof(rec));rows++;board[i]=0;
  }
  id++;if(id%1000==0)cerr<<"boards="<<id<<" rows="<<rows<<"\n";
 }
 cerr<<"complete boards="<<id<<" rows="<<rows<<"\n";
}
