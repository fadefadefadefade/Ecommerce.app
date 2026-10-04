<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UserAddress;
use Illuminate\Http\Request;

class AddressController extends Controller
{
    public function index(Request $request)
    {
        $addresses = $request->user()
            ->addresses()
            ->orderByDesc('is_default')
            ->oldest()
            ->get();

        return response()->json([
            'addresses' => $addresses->map(function ($address) {
                return [
                    'id' => $address->id,
                    'label' => $address->label,
                    'full_name' => $address->full_name,
                    'phone' => $address->phone,
                    'address_line' => $address->address_line,
                    'barangay' => $address->barangay,
                    'city' => $address->city,
                    'province' => $address->province,
                    'zip' => $address->zip,
                    'country' => $address->country,
                    'is_default' => $address->is_default,
                    'full_address' => $address->full_address,
                ];
            }),
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'label'        => 'required|string|max:50',
            'full_name'    => 'required|string|max:255',
            'phone'        => 'nullable|string|max:30',
            'address_line' => 'required|string|max:255',
            'barangay'     => 'nullable|string|max:120',
            'city'         => 'required|string|max:120',
            'province'     => 'nullable|string|max:120',
            'zip'          => 'nullable|string|max:20',
            'country'      => 'nullable|string|max:100',
            'is_default'   => 'boolean',
        ]);

        $user = $request->user();
        $data['user_id'] = $user->id;
        $data['country'] = $data['country'] ?? 'Philippines';

        // If marking as default, clear existing default first
        if (!empty($data['is_default'])) {
            $user->addresses()->update(['is_default' => false]);
        }

        // If this is the first address, auto-set as default
        if ($user->addresses()->count() === 0) {
            $data['is_default'] = true;
        }

        $address = UserAddress::create($data);

        return response()->json([
            'message' => 'Address added successfully.',
            'address' => [
                'id' => $address->id,
                'label' => $address->label,
                'full_name' => $address->full_name,
                'phone' => $address->phone,
                'address_line' => $address->address_line,
                'barangay' => $address->barangay,
                'city' => $address->city,
                'province' => $address->province,
                'zip' => $address->zip,
                'country' => $address->country,
                'is_default' => $address->is_default,
                'full_address' => $address->full_address,
            ],
        ]);
    }

    public function update(Request $request, int $id)
    {
        $address = UserAddress::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();

        $data = $request->validate([
            'label'        => 'required|string|max:50',
            'full_name'    => 'required|string|max:255',
            'phone'        => 'nullable|string|max:30',
            'address_line' => 'required|string|max:255',
            'barangay'     => 'nullable|string|max:120',
            'city'         => 'required|string|max:120',
            'province'     => 'nullable|string|max:120',
            'zip'          => 'nullable|string|max:20',
            'country'      => 'nullable|string|max:100',
            'is_default'   => 'boolean',
        ]);

        $makeDefault = !empty($data['is_default']);

        if ($makeDefault) {
            $request->user()->addresses()->update(['is_default' => false]);
            $data['is_default'] = true;
        } else {
            unset($data['is_default']);
        }

        $address->update($data);

        return response()->json([
            'message' => 'Address updated successfully.',
            'address' => [
                'id' => $address->id,
                'label' => $address->label,
                'full_name' => $address->full_name,
                'phone' => $address->phone,
                'address_line' => $address->address_line,
                'barangay' => $address->barangay,
                'city' => $address->city,
                'province' => $address->province,
                'zip' => $address->zip,
                'country' => $address->country,
                'is_default' => $address->is_default,
                'full_address' => $address->full_address,
            ],
        ]);
    }

    public function destroy(Request $request, int $id)
    {
        $address = UserAddress::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();

        $wasDefault = $address->is_default;
        $address->delete();

        // Promote the oldest remaining address to default
        if ($wasDefault) {
            $request->user()->addresses()->oldest()->first()?->update(['is_default' => true]);
        }

        return response()->json([
            'message' => 'Address removed.',
        ]);
    }

    public function setDefault(Request $request, int $id)
    {
        $address = UserAddress::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();

        $request->user()->addresses()->update(['is_default' => false]);
        $address->update(['is_default' => true]);

        return response()->json([
            'message' => 'Default address updated.',
        ]);
    }
}
