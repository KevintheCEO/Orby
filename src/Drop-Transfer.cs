using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Automation;

public sealed class OrbyDropNode {
 public AutomationElement Element;
 public string Name,Help,Id,Class;
 public ControlType Type;
 public bool Offscreen,Enabled;
}
public static class OrbyDropTransfer {
 public static OrbyDropNode[] Nodes(AutomationElement root) {
  for(int attempt=0;;attempt++){
   try{return ReadNodes(root);}catch(COMException){if(attempt>=2)throw;Thread.Sleep(30);}
  }
 }
 static OrbyDropNode[] ReadNodes(AutomationElement root){
  var request=new CacheRequest();request.TreeScope=TreeScope.Element;
  foreach(var property in new[]{AutomationElement.NameProperty,AutomationElement.HelpTextProperty,AutomationElement.AutomationIdProperty,AutomationElement.ClassNameProperty,AutomationElement.ControlTypeProperty,AutomationElement.IsOffscreenProperty,AutomationElement.IsEnabledProperty})request.Add(property);
  var nodes=new List<OrbyDropNode>();
  using(request.Activate()){
   foreach(AutomationElement element in root.FindAll(TreeScope.Descendants,Condition.TrueCondition)){
    try{var c=element.Cached;nodes.Add(new OrbyDropNode{Element=element,Name=c.Name,Help=c.HelpText,Id=c.AutomationId,Class=c.ClassName,Type=c.ControlType,Offscreen=c.IsOffscreen,Enabled=c.IsEnabled});}catch(ElementNotAvailableException){}catch(COMException){}
   }
  }
  return nodes.ToArray();
 }
}
