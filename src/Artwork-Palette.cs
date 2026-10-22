using System;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
public static class OrbyArtworkPalette {
 public static Color Sample(BitmapSource bitmap){
  if(bitmap==null||bitmap.PixelWidth<=0||bitmap.PixelHeight<=0)return Colors.Transparent;
  try{
   var small=new TransformedBitmap(bitmap,new ScaleTransform(32.0/bitmap.PixelWidth,32.0/bitmap.PixelHeight));
   var pixels=new FormatConvertedBitmap(small,PixelFormats.Bgra32,null,0);int stride=pixels.PixelWidth*4;
   var bytes=new byte[stride*pixels.PixelHeight];pixels.CopyPixels(bytes,stride,0);
   int count=bytes.Length/4;var hues=new double[count];var weights=new double[count];var bins=new double[24];int opaque=0,chromatic=0;
   for(int i=0;i<count;i++){
    int offset=i*4;double alpha=bytes[offset+3]/255.0;if(alpha<.5)continue;opaque++;
    double r=bytes[offset+2],g=bytes[offset+1],b=bytes[offset],max=Math.Max(r,Math.Max(g,b)),min=Math.Min(r,Math.Min(g,b));
    double delta=max-min,saturation=max>0?delta/max:0;
    // Neutral text/highlights and near-black pixels must not wash blue art white.
    if(max<32||saturation<.22)continue;
    double hue=max==r?60*((g-b)/delta):max==g?60*(2+(b-r)/delta):60*(4+(r-g)/delta);if(hue<0)hue+=360;
    double weight=alpha*saturation*saturation*(.25+.75*max/255.0);hues[i]=hue;weights[i]=weight;bins[Math.Min(23,(int)(hue/15))]+=weight;chromatic++;
   }
   if(opaque==0||chromatic<Math.Max(3,opaque*.03))return Colors.Transparent;
   // Pick a dominant hue family rather than averaging conflicting colors to gray.
   int best=0;double score=-1;for(int i=0;i<24;i++){double s=bins[i]+.5*(bins[(i+23)%24]+bins[(i+1)%24]);if(s>score){best=i;score=s;}}
   double center=best*15+7.5,total=0,red=0,green=0,blue=0;int selected=0;
   for(int i=0;i<count;i++){if(weights[i]<=0)continue;double distance=Math.Abs(hues[i]-center);distance=Math.Min(distance,360-distance);if(distance>22.5)continue;int offset=i*4;double w=weights[i];total+=w;red+=bytes[offset+2]*w;green+=bytes[offset+1]*w;blue+=bytes[offset]*w;selected++;}
   if(total<=0||selected<Math.Max(3,opaque*.03))return Colors.Transparent;
   // A small colored patch on mostly black art gets a smaller, darker glow.
   byte strength=(byte)Math.Round(110*Math.Min(1,selected/(opaque*.25)));
   return Color.FromArgb(strength,(byte)Math.Round(red/total),(byte)Math.Round(green/total),(byte)Math.Round(blue/total));
  }catch{return Colors.Transparent;}
 }
}
