using System;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using Microsoft.Win32;
public static class DropPickerFixture {
 [STAThread] public static void Main(string[] args){
  var form=new Window{Title="Orby owned picker fixture",Width=500,Height=260};
  var panel=new StackPanel();form.Content=panel;
  var attach=new Button{Content="Add files",Width=160,Height=40};
  var menu=new Menu();var add=new MenuItem{Header="Add files"};var upload=new MenuItem{Header="Upload or add files"};add.Items.Add(upload);menu.Items.Add(add);
  bool wizard=args.Length>1&&args[1]=="wizard";if(wizard)panel.Children.Add(menu);else panel.Children.Add(attach);
  var choose=new Button{Content="Choose files",Visibility=Visibility.Collapsed};panel.Children.Add(choose);
  var names=new TextBlock();panel.Children.Add(names);
  Action pick=()=>{var dialog=new OpenFileDialog{Multiselect=true};
   if(dialog.ShowDialog(form)==true){names.Text=string.Join(";",dialog.FileNames);File.WriteAllLines(args[0],dialog.FileNames);}
  };
  attach.Click+=(s,e)=>pick();upload.Click+=(s,e)=>{menu.Visibility=Visibility.Collapsed;choose.Visibility=Visibility.Visible;};choose.Click+=(s,e)=>pick();
  new Application().Run(form);
 }
}
