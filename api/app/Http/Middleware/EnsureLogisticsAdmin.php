<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Logistics panel is admin-only, same as the web app's logistics login. */
class EnsureLogisticsAdmin
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->user()?->role !== 'admin') {
            return response()->json([
                'message' => 'You do not have permission to access the logistics panel.',
            ], 403);
        }

        return $next($request);
    }
}
