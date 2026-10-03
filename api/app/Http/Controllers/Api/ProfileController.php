<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class ProfileController extends Controller
{
    public function show(Request $request)
    {
        $user = $request->user();
        
        return response()->json([
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'bio' => $user->bio,
                'sex' => $user->sex,
                'birthday' => $user->birthday?->format('Y-m-d'),
                'role' => $user->role,
                'profile_photo_path' => $user->profile_photo_path 
                    ? asset('storage/' . $user->profile_photo_path) 
                    : null,
            ],
        ]);
    }

    public function update(Request $request)
    {
        $user = $request->user();

        $data = $request->validate([
            'name'     => 'required|string|max:255',
            'email'    => ['required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($user->id)],
            'phone'    => 'nullable|string|max:30',
            'bio'      => 'nullable|string|max:500',
            'sex'      => 'nullable|in:Male,Female',
            'birthday' => 'nullable|date|before:today',
            'avatar'   => 'nullable|image|mimes:jpg,jpeg,png,webp|max:2048',
        ]);

        // Handle profile picture upload
        if ($request->hasFile('avatar')) {
            // Remove the previous photo if it exists
            if ($user->profile_photo_path) {
                Storage::disk('public')->delete($user->profile_photo_path);
            }
            $data['profile_photo_path'] = $request->file('avatar')->store('avatars', 'public');
        }

        // avatar is not a DB column
        unset($data['avatar']);

        $user->update($data);

        return response()->json([
            'message' => 'Profile updated successfully.',
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'bio' => $user->bio,
                'sex' => $user->sex,
                'birthday' => $user->birthday?->format('Y-m-d'),
                'role' => $user->role,
                'profile_photo_path' => $user->profile_photo_path 
                    ? asset('storage/' . $user->profile_photo_path) 
                    : null,
            ],
        ]);
    }
}
