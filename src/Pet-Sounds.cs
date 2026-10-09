using System;
using System.IO;
using System.Media;
using System.Collections.Generic;
public static class OrbyTones {
 static Dictionary<string,SoundPlayer> players=new Dictionary<string,SoundPlayer>();
 static DateTime last=DateTime.MinValue;
 public static byte[] Wave(string kind){
  if(kind=="water")return WaterDing();
  double[] notes=kind=="success"?new double[]{660,880}:kind=="attention"?new double[]{620,740}:kind=="error"?new double[]{440,330}:kind=="idle"?new double[]{700,820}:new double[]{820};
  const int rate=22050;int per=(int)(rate*(kind=="tap"?0.065:0.115)),count=per*notes.Length;
  using(var stream=new MemoryStream())using(var w=new BinaryWriter(stream)){
   w.Write(System.Text.Encoding.ASCII.GetBytes("RIFF"));w.Write(36+count*2);w.Write(System.Text.Encoding.ASCII.GetBytes("WAVEfmt "));
   w.Write(16);w.Write((short)1);w.Write((short)1);w.Write(rate);w.Write(rate*2);w.Write((short)2);w.Write((short)16);
   w.Write(System.Text.Encoding.ASCII.GetBytes("data"));w.Write(count*2);
   for(int i=0;i<count;i++){double t=(i%per)/(double)rate,p=(i%per)/(double)per;double envelope=Math.Sin(Math.PI*p)*Math.Exp(-3*p);double gain=kind=="idle"?0.025:0.07;w.Write((short)(32767*gain*envelope*Math.Sin(2*Math.PI*notes[i/per]*t)));}
   return stream.ToArray();
  }
 }
 public static void Play(string kind){
  if(kind!="water"&&(DateTime.UtcNow-last).TotalSeconds<(kind=="idle"?15:1.8))return;
  last=DateTime.UtcNow;SoundPlayer player;
  if(!players.TryGetValue(kind,out player)){player=new SoundPlayer(new MemoryStream(Wave(kind)));player.Load();players[kind]=player;}
  player.Play();
 }
 public static void Close(){foreach(var player in players.Values){player.Stop();player.Dispose();}players.Clear();}
 static byte[] WaterDing(){
  const int rate=22050,count=22050;
  using(var stream=new MemoryStream())using(var w=new BinaryWriter(stream)){
   w.Write(System.Text.Encoding.ASCII.GetBytes("RIFF"));w.Write(36+count*2);w.Write(System.Text.Encoding.ASCII.GetBytes("WAVEfmt "));w.Write(16);w.Write((short)1);w.Write((short)1);w.Write(rate);w.Write(rate*2);w.Write((short)2);w.Write((short)16);w.Write(System.Text.Encoding.ASCII.GetBytes("data"));w.Write(count*2);
   for(int i=0;i<count;i++){double t=i/(double)rate;double attack=Math.Min(1,t/.006);double bell=(Math.Sin(2*Math.PI*1046.5*t)+.32*Math.Sin(2*Math.PI*2093*t)+.12*Math.Sin(2*Math.PI*3139.5*t))*Math.Exp(-5*t)*attack;w.Write((short)(32767*.18*bell));}return stream.ToArray();
  }
 }
}
