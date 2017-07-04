"""This tool converts the images under a directory (including subdirs) into an RGBDS asm include file.
It scans for *.json files that contain the keys:
	"image": The target image file, absolute or relative to this file.
	"pallette": The pallette (mapping from image pixel values to GB data values).
	            This should take the form of a 4-item list of pixel values, mapping
	            to GB data values 0-3 respectively. Pixel values depend on the mode of the image,
	            eg. a 3-item list [R, G, B] for color images, a simple integer for greyscale.
	"length": Optional. Number of tiles in the image. If not given, is worked out from image size.
	"name": Optional. The name of the include file to produce. Defaults to the json file's name (not including .json suffix).

Images are scanned for tiles left-to-right, then top-to-bottom. eg. in a 32x16 image, the tiles would be numbered:
	1234
	5678

For each json file / image file, it produces an asm file in the output directory that defines the data.
"""

import json
import os
import sys
import traceback

try:
	from PIL import Image
except ImportError:
	sys.stderr.write("This tool requires the Python Image Library or equivalent.\n"
	                 "The best way to install it is using pip: pip install pillow")
	raise


def main(targetdir, outdir):
	for path, dirs, files in os.walk(targetdir):
		for filename in files:
			if not filename.endswith('.json'):
				continue
			filepath = os.path.join(path, filename)
			try:
				process_file(targetdir, filepath, outdir)
			except Exception:
				sys.stderr.write("An error occurred while processing file {!r}:".format(filepath))
				traceback.print_exc()


def process_file(targetdir, filepath, outdir):
	filepath_dir = os.path.dirname(filepath)

	with open(filepath) as f:
		meta = json.load(f)

	imagepath = meta['image']
	if not os.path.isabs(imagepath):
		imagepath = os.path.join(filepath_dir, imagepath)

	name = meta.get('name', os.path.basename(filepath)[:-len('.json')])
	image = Image.open(imagepath)

	tiles = image_to_tiles(image, meta['pallette'], meta.get('length'))
	text = tiles_to_text(filepath, tiles)

	outpath_dir = os.path.join(outdir, os.path.relpath(filepath_dir, targetdir))
	outpath = os.path.join(outpath_dir, '{}.asm'.format(name))

	if not os.path.isdir(outpath_dir):
		os.makedirs(outpath_dir)
	with open(outpath, 'w') as f:
		f.write(text)


def image_to_tiles(image, pallette, length=None):
	width, height = image.size

	if len(pallette) != 4:
		raise ValueError("pallette must be exactly 4 items")
	pallette = {value: index for index, value in enumerate(pallette)}

	tiles = []
	for row in range(height / 8):
		for col in range(width / 8):
			tiles.append(extract_tile(image, row, col, pallette))
			if length is not None and len(tiles) == length:
				return tiles

	return tiles


def extract_tile(image, row, col, pallette):
	tile = []
	for y in range(row * 8, (row + 1) * 8):
		line = []
		for x in range(col * 8, (col + 1) * 8):
			pixel = image.getpixel((x, y))
			if pixel not in pallette:
				raise Exception("Pixel ({}, {}) = {} is not a value in the pallette".format(x, y, pixel))
			value = pallette[pixel]
			line.append(value)
		tile.append(line)
	return tile


def tiles_to_text(filepath, tiles):
	tiles = '\n\n'.join(tile_to_text(tile) for tile in tiles)
	return "; Generated from {}\n\n{}\n".format(filepath, tiles)


def tile_to_text(tile):
	return '\n'.join(
		"dw `{}".format(''.join(map(str, line)))
		for line in tile
	)


if __name__ == '__main__':
	import argh
	argh.dispatch_command(main)
