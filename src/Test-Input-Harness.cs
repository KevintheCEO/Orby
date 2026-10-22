using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Automation;
using System.Windows.Interop;
using System.Windows.Threading;

public static class OrbyInputHarness {
 static int checks,submits;static Window window;static StackPanel root,card;static TextBlock prompt;static Button send;static RadioButton first,second;
 static void Check(bool value,string message){if(!value)throw new Exception(message);checks++;}
 static void UI(Action action){window.Dispatcher.Invoke(action);}
 static void Form(){
  card=new StackPanel{Margin=new Thickness(10)};root.Children.Clear();root.Children.Add(new GroupBox{Header="Input card",Content=card});
  card.Children.Add(new TextBlock{Text="Question"});prompt=new TextBlock{Text="Please quit Orby so the update can finish."};card.Children.Add(prompt);
  first=new RadioButton{Content="Orby is closed",Margin=new Thickness(4)};second=new RadioButton{Content="I'll install later",Margin=new Thickness(4)};
  card.Children.Add(first);card.Children.Add(second);
  send=new Button{Content="Send",IsEnabled=false,Margin=new Thickness(4)};
  first.Checked+=(s,e)=>send.IsEnabled=true;second.Checked+=(s,e)=>send.IsEnabled=true;
  send.Click+=(s,e)=>{submits++;root.Children.Clear();root.Children.Add(new TextBlock{Text="Working..."});};
  card.Children.Add(new Button{Content="Skip",Margin=new Thickness(4)});card.Children.Add(send);
 }
 public static void Run(){
  window=new Window{Width=640,Height=480,Title="Orby input test fixture",ShowActivated=false};root=new StackPanel();window.Content=root;Form();
  Exception failure=null;Task test=null;
  window.Loaded+=(s,e)=>{
   IntPtr hwnd=new WindowInteropHelper(window).Handle;
   test=Task.Run(()=>{
    try{
     var element=AutomationElement.FromHandle(hwnd);var q=OrbyApprovalWorker.InspectRoot(element);
     Check(q.Available&&q.Kind=="question"&&q.CanAnswer,"Visible question with disabled Send was missed");
     Check(q.Choices.Length==2&&q.Choices[0]=="Orby is closed","Choices were not exact");
     Check(q.Title.Contains("Please quit Orby"),"Question prompt missing");
     Check(submits==0,"Reading a question submitted a response");
     Check(!OrbyApprovalWorker.RespondToRoot(element,q.Id,true).Submitted,"Question exposed a permission approval action");
     Check(!OrbyApprovalWorker.AnswerToRoot(element,q.Id,99).Submitted,"Out-of-range answer submitted");
     UI(()=>prompt.Text="Changed question: review before sending.");
     Check(!OrbyApprovalWorker.AnswerToRoot(element,q.Id,0).Submitted&&submits==0,"Stale question accepted an answer");
     var changed=OrbyApprovalWorker.InspectRoot(element);
     var reply=OrbyApprovalWorker.AnswerToRoot(element,changed.Id,1);
     Check(reply.Submitted&&reply.Resolved&&submits==1,"Explicit choice was not selected and sent");
     Check(!OrbyApprovalWorker.AnswerToRoot(element,changed.Id,1).Submitted&&submits==1,"Old answer replayed after form disappeared");
     UI(()=>{root.Children.Clear();root.Children.Add(new TextBlock{Text="Question: please confirm the reminder"});root.Children.Add(new Button{Content="Send"});});
     Check(!OrbyApprovalWorker.InspectRoot(element).Available,"Chat prose mistaken for a blocking question");
     UI(()=>{Form();card.Children.Add(new Button{Content="Send"});});
     Check(!OrbyApprovalWorker.InspectRoot(element).Available,"Ambiguous multiple-submit form became actionable");
     UI(()=>{
      root.Children.Clear();var p=new StackPanel{Margin=new Thickness(8)};root.Children.Add(new GroupBox{Header="Permission card",Content=p});
      p.Children.Add(new TextBlock{Text="Allow ChatGPT to access the internet?"});p.Children.Add(new TextBlock{Text="Network request details"});
      var yes=new Button{Content="Allow once"};var no=new Button{Content="Deny"};
      yes.Click+=(a,b)=>{submits++;root.Children.Clear();};p.Children.Add(yes);p.Children.Add(no);
     });
     var permission=OrbyApprovalWorker.InspectRoot(element);
     Check(permission.Available&&permission.Kind=="permission","Existing permission inspection broke");
     Check(!OrbyApprovalWorker.AnswerToRoot(element,permission.Id,0).Submitted,"Question answer used on a permission request");
     Check(OrbyApprovalWorker.RespondToRoot(element,permission.Id,true).Submitted&&submits==2,"Existing permission reply broke");
    }catch(Exception error){failure=error;}
   });
  };
  var timer=new DispatcherTimer{Interval=TimeSpan.FromMilliseconds(40)};var watch=System.Diagnostics.Stopwatch.StartNew();
  timer.Tick+=(s,e)=>{if((test!=null&&test.IsCompleted)||watch.Elapsed.TotalSeconds>25){if(test==null||!test.IsCompleted)failure=new Exception("UI automation test timed out");timer.Stop();window.Close();}};
  timer.Start();window.ShowDialog();if(failure!=null)throw failure;
  Console.WriteLine("PASS: "+checks+" native accessibility question/permission checks; no response sent without explicit test action");
 }
}
