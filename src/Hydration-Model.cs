using System;
namespace OrbyWater {
 public sealed class ActiveDayClock {
  public string Date;public double ActiveSeconds;DateTime last;bool wasActive;
  public TimeSpan Elapsed{get{return TimeSpan.FromSeconds(ActiveSeconds);}}
  public ActiveDayClock(){Date=DateTime.Now.ToString("yyyy-MM-dd");last=DateTime.Now;}
  public void Restore(string date,double seconds,DateTime now){Date=now.ToString("yyyy-MM-dd");ActiveSeconds=date==Date?Math.Max(0,Math.Min(86400,seconds)):0;last=now;wasActive=false;}
  public void Tick(DateTime now,bool active){double gap=(now-last).TotalSeconds;string date=now.ToString("yyyy-MM-dd");if(date!=Date){Date=date;ActiveSeconds=0;}else if(active&&wasActive&&gap>0&&gap<=5){ActiveSeconds+=gap;}last=now;wasActive=active;}
 }
 public static class InputActivity {
  [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]struct Stamp{public uint Size,Tick;}
  [System.Runtime.InteropServices.DllImport("user32.dll")]static extern bool GetLastInputInfo(ref Stamp stamp);
  [System.Runtime.InteropServices.DllImport("user32.dll")]static extern IntPtr OpenInputDesktop(uint flags,bool inherit,uint access);
  [System.Runtime.InteropServices.DllImport("user32.dll")]static extern bool CloseDesktop(IntPtr desktop);
  public static bool Active(){var stamp=new Stamp{Size=8};if(!GetLastInputInfo(ref stamp)||unchecked((uint)Environment.TickCount-stamp.Tick)>300000)return false;var desktop=OpenInputDesktop(0,false,1);if(desktop==IntPtr.Zero)return false;CloseDesktop(desktop);return true;}
 }
 public sealed class SipPlan {
  public readonly int GoalMl,EstimateMl,Hours,Count;
  public readonly double IntervalSeconds,EndSeconds;
  public SipPlan(int goal,int estimate,int hours){
   if(goal<1||estimate<1||hours<1)throw new ArgumentOutOfRangeException();
   GoalMl=goal;EstimateMl=estimate;Hours=hours;Count=(int)Math.Ceiling(goal/(double)estimate);EndSeconds=hours*3600.0;IntervalSeconds=EndSeconds/Count;
  }
  public double Next(double elapsed){return (Math.Floor(Math.Max(0,elapsed)/IntervalSeconds)+1)*IntervalSeconds;}
  public bool Due(double elapsed,double deadline,int estimatedTotal,bool enabled){return enabled&&estimatedTotal<GoalMl&&deadline<=EndSeconds+.001&&elapsed<=EndSeconds+.001&&elapsed>=deadline;}
 }
 // Local clock and confirmed intake only; reminders never increment intake.
 public sealed class Day {
  public string Date=""; public int TotalMl; public DateTime NextReminder=DateTime.MinValue;
  public bool Testing; public bool Enabled=true; public int GoalMl=3000,DrinkMl=250,IntervalMinutes=75,WakeHour=8,SleepHour=23;
  public int Percent { get { return Math.Min(100,(int)Math.Round(100.0*TotalMl/Math.Max(1,GoalMl))); } }
  public bool Awake(DateTime now){return WakeHour<SleepHour?now.Hour>=WakeHour&&now.Hour<SleepHour:now.Hour>=WakeHour||now.Hour<SleepHour;}
  public bool RollDate(DateTime now){string today=now.ToString("yyyy-MM-dd");if(Date==today)return false;Date=today;TotalMl=0;NextReminder=now.AddMinutes(IntervalMinutes);return true;}
  public bool Due(DateTime now,bool quiet,bool blocked){RollDate(now);return !blocked&&now>=NextReminder&&(Testing||(Enabled&&!quiet&&Awake(now)&&TotalMl<GoalMl));}
  public void Reminded(DateTime now){NextReminder=now.AddMinutes(IntervalMinutes);}
  public void Snooze(DateTime now){NextReminder=now.AddMinutes(15);}
  public void Confirm(DateTime now){RollDate(now);TotalMl+=DrinkMl;NextReminder=now.AddMinutes(IntervalMinutes);}
 }
}
