namespace ShellTabRailRepro;

public partial class MainPage : ContentPage
{
    public MainPage()
    {
        InitializeComponent();
    }

    protected override void OnAppearing()
    {
        base.OnAppearing();
        TabLabel.Text = Shell.Current?.CurrentItem?.CurrentItem?.Title ?? "";
    }
}
