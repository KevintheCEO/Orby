using System;
using System.Collections.Generic;
using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
public static class OrbyRenderedAssets {
 static string folder;
 static readonly Dictionary<string,BitmapSource> images=new Dictionary<string,BitmapSource>();
 static readonly Dictionary<string,Brush> bodies=new Dictionary<string,Brush>();
 public static void Configure(string path){folder=Path.Combine(path,"Rendered-assets");}
 public static BitmapSource Image(string name){
  BitmapSource image;if(images.TryGetValue(name,out image))return image;
  if(folder==null)throw new InvalidOperationException("Orby rendered assets not configured.");
  var bitmap=new BitmapImage();bitmap.BeginInit();bitmap.CacheOption=BitmapCacheOption.OnLoad;bitmap.UriSource=new Uri(Path.Combine(folder,name+".png"));bitmap.EndInit();bitmap.Freeze();images.Add(name,bitmap);return bitmap;
 }
 public static Brush Body(Color tint){
  string key=tint.ToString();Brush brush;if(bodies.TryGetValue(key,out brush))return brush;
  var original=new FormatConvertedBitmap(Image("body"),PixelFormats.Bgra32,null,0);int w=original.PixelWidth,h=original.PixelHeight,stride=w*4;byte[] pixels=new byte[stride*h];original.CopyPixels(pixels,stride,0);
  bool white=tint.R>230&&tint.G>230&&tint.B>230;
  if(!white){for(int i=0;i<pixels.Length;i+=4){
   double light=(pixels[i]*.0722+pixels[i+1]*.7152+pixels[i+2]*.2126)/255.0;
   double highlight=Math.Max(0,(light-.83)*2.1);
   pixels[i]=(byte)Math.Min(255,tint.B*light+(255-tint.B)*highlight);
   pixels[i+1]=(byte)Math.Min(255,tint.G*light+(255-tint.G)*highlight);
   pixels[i+2]=(byte)Math.Min(255,tint.R*light+(255-tint.R)*highlight);
  }}
  var source=BitmapSource.Create(w,h,96,96,PixelFormats.Bgra32,null,pixels,stride);source.Freeze();brush=new ImageBrush(source){Stretch=Stretch.Fill};brush.Freeze();bodies.Add(key,brush);return brush;
 }
}
