<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use App\Models\User;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email' => 'required|email',
            'password' => 'required',
        ]);

        if (!Auth::attempt($credentials)) {
            return response()->json([
                'message' => 'These credentials do not match our records.',
            ], 401);
        }

        $user = Auth::user();
        
        // Create token
        $token = $user->createToken('mobile-app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role ?? 'buyer',
                'approval_status' => $user->approval_status ?? 'approved',
                'created_at' => $user->created_at,
                'last_login_at' => $user->last_login_at,
            ],
        ]);
    }

    public function register(Request $request)
    {
        $validated = $request->validate([
            'last_name'      => 'required|string|max:255',
            'first_name'     => 'required|string|max:255',
            'middle_initial' => 'nullable|string|max:5',
            'username'       => 'required|string|max:50|unique:users,username',
            'password'       => 'required|string|min:8|confirmed',
            'sex'            => 'required|in:Male,Female',
            'email'          => 'required|string|email|max:255|unique:users,email',
            'contact_no'     => 'required|string|max:20',
            'birthday'       => 'required|date|before:today',
            'age'            => 'required|integer|min:0|max:150',
            'region'         => 'required|string|max:255',
            'province'       => 'required|string|max:255',
            'municipality'   => 'required|string|max:255',
            'barangay'       => 'required|string|max:255',
            'zip_code'       => 'nullable|string|max:20',
            'house_number'   => 'required|string|max:50',
            'street'         => 'required|string|max:255',
        ]);

        $user = User::create([
            'name'            => trim($validated['first_name'] . ' ' . $validated['last_name']),
            'first_name'      => $validated['first_name'],
            'last_name'       => $validated['last_name'],
            'middle_initial'  => $validated['middle_initial'] ?? null,
            'username'        => $validated['username'],
            'email'           => $validated['email'],
            'password'        => Hash::make($validated['password']),
            'role'            => 'buyer',
            'sex'             => $validated['sex'],
            'contact_no'      => $validated['contact_no'],
            'birthday'        => $validated['birthday'],
            'age'             => $validated['age'],
            'region'          => $validated['region'],
            'province'        => $validated['province'],
            'municipality'    => $validated['municipality'],
            'barangay'        => $validated['barangay'],
            'zip_code'        => $validated['zip_code'],
            'house_number'    => $validated['house_number'],
            'street'          => $validated['street'],
            'approval_status' => 'pending',
        ]);

        return response()->json([
            'message' => 'Registration submitted successfully. Your account is currently pending administrator approval.',
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
            ],
        ], 201);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'Logged out successfully',
        ]);
    }

    public function user(Request $request)
    {
        return response()->json([
            'user' => $request->user(),
        ]);
    }
}
