// Public compatibility surface. Personal water visuals are not distributed.
using System.Windows.Controls;
using System.Windows.Media;
public sealed partial class OrbyAvatarRenderer {
 static Geometry happyWaterLeft {get{return geometries[0];}}
 static Geometry happyWaterRight {get{return geometries[1];}}
 public double WaterProgress;
 public bool WaterVisible {get{return false;}}
 public string WaterProgressText {get{return "";}}
 public bool RenderedWaterAssetsLoaded {get{return false;}}
 public void StopWater(){}
 void BuildRenderedDetails(Canvas face){arms.Stroke=new SolidColorBrush(Color.FromRgb(225,229,227));arms.StrokeThickness=3;cup.Background=new SolidColorBrush(Color.FromRgb(225,229,227));}
 void BuildWaterBottle(){}
 void DrawWater(double elapsed,double progress){}
}
