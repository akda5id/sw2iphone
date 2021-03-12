# sw2iphone
A command line tool to export [Swinsian](https://swinsian.com/) playlists to iTunes/Music and sync back playcounts and ratings.
* Converts FLAC files to mp3 (requires sox and lame) as needed. Tries (not too hard) to find cover images (cover.jpg, etc), and include them (requires metaflac).
* Reads song data from the iTunesLibrary Framework (macOS 10.15+). (Thanks to code from the [idbcl](https://github.com/jmkerr/idbcl/) project.)
* Keeps track of files being removed from iTunes, so that we can keep proper count of playcount, and remove files from disk that we transcoded.
### Install:
* Download `sw2iphone.zip` from the latest [release](https://github.com/akda5id/sw2iphone/releases/tag/v0.3.0) and extract it and place it somewhere in your $PATH (or reference it directly).
* If you have FLAC files you want to sync, make sure you have sox, lame, and metaflac installed in /usr/local/bin/. Recommend installing with [homebrew](https://brew.sh/) for ease: `brew install flac`,  `brew install lame` and `brew install sox`.
#### Usage:
`sw2iphone -h` will give the commands, but here is what you need to know:
* By default we will use the directory `~/Music/sw2iphone` as our export folder for playlists, and any mp3s we create. You can change this by passing in a path after `--path`. If you do change the path after mp3s have been created in the old path, be aware that we don't do anything to move them, and they will be recreated next time you export the playlist, and things will get funky (duplicated tracks in iTunes). Recommend you set the path to what you want from the start, and if you do change it later, either manually move over the files to the new directory **before** you run anything with sw2iphone, or start fresh in iTunes. We do save the path, you don't have to pass it each time, just when you want to change it.
* On first run it will probably ask you if you want "Terminal to be able to control Swinsian". This is the sandbox permission request for AppleScript to work with Swinsian. You should say yes.
*  `--v` or `--vv` (and super secret option `--vvv`) will increase the amount of verbosity. Whichever is largest will be used, you don't need to include them all.
*  You can use the above along with `--dry-run` to get a feel for what sw2iphone will do on the run, with this flag we won't create files on disk (other than temp files, which we clean up), or make changes to the Swinsian database.
*  For more see the workflows section below for examples.
#### Status and future features:
This is a tool I hacked up to fill a need of mine (to get music from Swinsian to my iPhone, and sync back playcounts and ratings). It is pretty simple, and may break in bad ways if you are doing something other than my specific workflow (see workflows below). That said I think other people may have needs similar to mine, so I am releasing it here under the MIT license. And I do intend to continue work to clean it up, make it more robust, and add a few features. Send me mail if you have problems, requests or just to let me know you are using it.
##### Todo:
* Better progress messages and logging.
* There are some files that iTunes silently refuses to import, related to characters in the path name. I don't think it is my fault, as even dragging the file directly into iTunes doesn't work. But I should warn you when this happens, on sync, if there are files I have never seen in iTunes.
* Handle changing the path to our directory better. Perhaps link files, or keep track of previously used paths? Could get messy.
* Potential performance improvements. I am using AppleScript to push changes back to Swinsian, to get out of having to deal with the UI and other challenges of tag editing. This is kinda slow, so may be worth hitting the files directly and inserting changes into Swinsian's database. Also, I am intentionally single threaded, as I am on a laptop and a prefer not spinning my fans up, and I don't mind waiting a bit for my music to be ready. I suppose this is one of the first feature requests I am going to get however :p
* I only copy over the basic tags when we do a transcode from flac. I bet there are some more that people might want?
* I guess some configurability around lame and sox options would be nice to have. Though I think I have good defaults, I suppose a switch for -V 2 rather than -V 0 would be good. If you care you can just edit the code ;)
### Workflows:
For now, just one supported, mine :p
1) Run `sw2iphone -e` and pick which Swinsian playlist you want to export.
2) Drop the .m3u8 from the output directory (default `~/Music/sw2iphone`) into iTunes. (You have to do this manually as iTunesLibrary Framework is read only.)
3) Do whatever you want inside iTunes to sync files to your phone, or whatever. You can create smart playlists inside iTunes if you want, it doesn't have to be the playlist you imported that is synced. You can also import multiple playlists from Swinsian (by running `sw2iphone -e` again). We will keep track of playcounts and ratings for any files that we know about (that came in via any export from Swinsian). Other tracks existing inside of iTunes that we don't know about will be ignored.
4) Listen to things, rate them, etc.
5) Sync iTunes to your phone again to pick up playcounts, ratings.
6) Run `sw2iphone -s` to sync that info back into Swinsian.

That is the basic path, you can now return to 1, and continue. Note that before you run `sw2iphone -s`  again, you must quit Swinsian, as it doesn't persist changes to its' database until quit.

Optionally, if you want to clean up your iTunes database to remove files you no longer need, you can do the following:

7) Run `sw2iphone -e` on all the playlists you want again, and then add an `--age x` on your last, or on a separate run, where x is a number of minutes that is larger than the time since you started this round of playlist exports. This will produce a playlist of tracks that had previously been exported by us, but are no-longer in the last batch of exports. You can then import this playlist called `to_Delete` into iTunes, select all of the tracks in it, right click and choose `Delete from Library`.
8) Alternatively to 7, you can also track and delete tracks from iTunes on your own, perhaps with a smart playlist. Either method works fine, on the next `sw2iphone -s` we will detect the removed tracks. 
9) Optionally after 7, or 8, you can run `sw2iphone -s --clean`. This will remove any transcoded (mp3 conversions of FLAC files) that we created from disk.

iTunes ignores files that it already knows about when you import a playlist, so feel free to export playlists using `-e` as many times over as you like, even if most of the files are duplicates. (iTunes will create a duplicate play**list** though, so you will need to clean up old playlists on iTunes before bringing it in again.) I have a smart playlist in Swinsian for unplayed and unrated songs, and continuously export that, and bring it to my phone. Then as they get played and rated, the `-s` syncs back to Swinsian dropping those files from that playlist, which I export back to iTunes again, ad nauseam.

Note that if you delete files from iTunes, you **must** run a `sw2iphone -s` *before* adding them back, otherwise we will potentially lose playcounts.
