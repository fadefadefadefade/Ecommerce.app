<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;

Route::get('/', function () {
    return view('welcome');
});

// Serve public-disk files (product photos, avatars) through PHP.
// `php artisan serve` on Windows drops static file transfers to the Android
// emulator mid-download ("Connection closed while receiving data"), so there
// is deliberately no public/storage link in development. On a real web server
// (nginx/Apache) you can run `php artisan storage:link`; static files then
// take precedence over this route.
Route::get('/storage/{path}', function (string $path) {
    $disk = Storage::disk('public');
    $root = realpath($disk->path(''));
    try {
        $file = realpath($disk->path($path));
    } catch (\League\Flysystem\PathTraversalDetected) {
        abort(404);
    }

    // Only files inside storage/app/public (no ../ traversal)
    abort_unless($file && $root && str_starts_with($file, $root . DIRECTORY_SEPARATOR) && is_file($file), 404);

    $headers = [
        'Content-Type' => mime_content_type($file) ?: 'application/octet-stream',
        'Content-Length' => (string) filesize($file),
        'Cache-Control' => 'public, max-age=86400',
    ];

    if (! app()->runningInConsole() && PHP_SAPI === 'cli-server') {
        // The dev server closes the socket as soon as the script ends, which on
        // Windows can cut off the last few bytes before they reach the emulator.
        // Flush, then give the data a moment to drain before the connection closes.
        return response()->stream(function () use ($file) {
            readfile($file);
            flush();
            usleep(250_000);
        }, 200, $headers);
    }

    return response()->file($file, ['Cache-Control' => $headers['Cache-Control']]);
})->where('path', '.*');
