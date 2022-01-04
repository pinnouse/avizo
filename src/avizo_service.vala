using Gtk;
using GtkLayerShell;

[GtkTemplate (ui = "/org/danb/avizo/ui/avizo.ui")]
public class AvizoWindow : Gtk.Window
{
	public string image_path
	{
		set
		{
			if (value != "")
			{
				image.set_from_file(value);
			}
		}
	}

	public string image_resource
	{
		set
		{
			if (value != "")
			{
				image.set_from_resource(@"/org/danb/avizo/data/images/$(value).png");
			}
		}
	}

	public double progress { get; set; }

	private int _width = 248;
	public int width
	{
		get
		{
			return _width;
		}

		set
		{
			_width = value;

			set_default_size(_width, _height);
		}
	}

	private int _height = 232;
	public int height
	{
		get
		{
			return _height;
		}

		set
		{
			_height = value;

			set_default_size(_width, _height);
		}
	}

	public int padding { get; set; }

	public int block_height { get; set; }
	public int block_spacing { get; set; }
	public int block_count { get; set; }

	public Gdk.RGBA background { get; set; default = Gdk.RGBA(); }

	public Gdk.RGBA _foreground = Gdk.RGBA();
	public Gdk.RGBA foreground
	{
		get
		{
			return _foreground;
		}

		set
		{
			_foreground = value;

			image.opacity = double.min(1.0, _foreground.alpha * 2.0);
		}
	}

	[GtkChild]
	private unowned Gtk.Image image;

	public AvizoWindow()
	{
		_width = width;
		_height = height;

		set_default_size(_width, _height);

		var screen = get_screen();
		var visual = screen.get_rgba_visual();
		if (visual != null && screen.is_composited())
		{
			set_visual(visual);
		}

		draw.connect(on_draw);
	}

	private bool on_draw(Gtk.Widget widget, Cairo.Context ctx)
	{
		double block_width = (_width - 2 * padding -
		                      (double) ((block_count - 1) * block_spacing)) / block_count;

		double blocks_x = padding;
		double blocks_y = _height - padding - block_height;

		ctx.set_operator(Cairo.Operator.SOURCE);
		ctx.paint();

		ctx.set_operator(Cairo.Operator.CLEAR);
		draw_rect(ctx, 0, 0, _width, _height);

		ctx.set_operator(Cairo.Operator.SOURCE);
		ctx.set_source_rgba(background.red, background.green, background.blue, background.alpha);
		draw_round_rect(ctx, 0, 0, _width, _height, 16);

		ctx.set_source_rgba(background.red, background.green, background.blue, background.alpha / 1.5);

		for (int i = 0; i < block_count; i++)
		{
			draw_rect(ctx, blocks_x + (block_width + block_spacing) * i,
			               blocks_y,
			               block_width,
			               block_height);
		}

		ctx.set_source_rgba(foreground.red, foreground.green, foreground.blue, foreground.alpha);

		for (int i = 0; i < (int) (block_count * progress); i++)
		{
			draw_rect(ctx, blocks_x + (block_width + block_spacing) * i,
			               blocks_y,
			               block_width,
			               block_height);
		}

		ctx.set_operator(Cairo.Operator.OVER);

		return false;
	}

	private void draw_rect(Cairo.Context ctx, double x, double y, double w, double h)
	{
		ctx.line_to(x, y);
		ctx.line_to(x + w, y);
		ctx.line_to(x + w, y + h);
		ctx.line_to(x, y + h);
		ctx.close_path();
		ctx.fill();
	}

	private void draw_round_rect(Cairo.Context ctx, double x, double y, double w, double h, double r)
	{
		ctx.move_to(x + r, y);
		ctx.line_to(x + w - r, y);

		ctx.arc(x + w - r, y + r, r, -Math.PI / 2, 0);

		ctx.line_to(x + w, y + h - r);

		ctx.arc(x + w - r, y + h - r, r, 0, Math.PI / 2);

		ctx.line_to(x + r, y + h);

		ctx.arc(x + r, y + h - r, r, Math.PI / 2, Math.PI);

		ctx.line_to(x, y + r);

		ctx.arc(x + r, y + r, r, Math.PI, 3 * Math.PI / 2);

		ctx.close_path();
		ctx.fill();
	}
}


[DBus (name = "org.danb.avizo.service")]
public class AvizoService : GLib.Object
{
	private static string[] props = {
		"image_path", "image_resource", "progress", "width", "height", "padding",
		"block_height", "block_spacing", "block_count", "background", "foreground",
	};

	public string image_path { get; set; default = ""; }
	public string image_resource { get; set; default = "volume_muted"; }
	public double progress { get; set; default = 0.0; }
	public int width { get; set; default = 248; }
	public int height { get; set; default = 232; }
	public int padding { get; set; default = 24; }
	public int block_height { get; set; default = 10; }
	public int block_spacing { get; set; default = 2; }
	public int block_count { get; set; default = 20; }
	public Gdk.RGBA background { get; set; default = rgba(255, 255, 255, 0.5); }
	public Gdk.RGBA foreground { get; set; default = rgba(0, 0, 0, 0.5); }

	private AvizoWindow _window = null;
	private int _open_timeouts = 0;

	public AvizoService()
	{
		_window = new AvizoWindow();

		foreach (var prop_name in props)
		{
			bind_property(prop_name, _window, prop_name, BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
		}

		GtkLayerShell.init_for_window(_window);
		GtkLayerShell.auto_exclusive_zone_enable(_window);
		GtkLayerShell.set_layer(_window, GtkLayerShell.Layer.OVERLAY);
		GtkLayerShell.set_keyboard_interactivity(_window, false);
	}

	public void show(double seconds) throws DBusError, IOError
	{
		_window.show();
		_window.queue_draw();

		_open_timeouts++;
		Timeout.add((int) (seconds * 1000), () =>
		{
			_open_timeouts--;

			if (_open_timeouts == 0)
			{
				_window.hide();
			}

			return false;
		});
	}
}

Gdk.RGBA rgba(double red, double green, double blue, double alpha)
{
	var o = Gdk.RGBA();
	o.red = red;
	o.green = green;
	o.blue = blue;
	o.alpha = alpha;
	return o;
}

void on_bus_aquired(DBusConnection conn)
{
	try
	{
		conn.register_object("/org/danb/avizo/service", new AvizoService());
	}
	catch (IOError e)
	{
		stderr.printf("Could not register service\n");
	}
}

public void main(string[] args)
{
	Gtk.init(ref args);

	Bus.own_name(BusType.SESSION, "org.danb.avizo.service", BusNameOwnerFlags.NONE,
	             on_bus_aquired,
	             () => {},
	             () => stderr.printf("Could not aquire name\n"));

	new AvizoService();

	Gtk.main();
}
