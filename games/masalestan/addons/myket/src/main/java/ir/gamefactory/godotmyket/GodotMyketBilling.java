package ir.gamefactory.godotmyket;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentSender;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.IBinder;
import android.os.RemoteException;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.android.vending.billing.IInAppBillingService;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

/**
 * Godot 4 Android plugin for Myket in-app billing.
 *
 * Binds Myket's v3-compatible billing service directly, as Myket's own developer documentation
 * instructs. Deliberately self-contained: no third-party billing library is bundled, so the
 * shipped APK carries no code of uncertain licensing.
 *
 * The GDScript-facing API intentionally mirrors the Poolakey (Cafe Bazaar) plugin so one
 * `iap.gd` can drive either store.
 */
public class GodotMyketBilling extends GodotPlugin {

    private static final String TAG = "GodotMyketBilling";
    private static final String MYKET_PACKAGE = "ir.mservices.market";
    private static final String BIND_ACTION = "ir.mservices.market.InAppBillingService.BIND";
    private static final String ITEM_TYPE = "inapp";
    private static final int API_VERSION = 3;
    private static final int PURCHASE_REQUEST = 11711;

    // response bundle keys, fixed by the v3 protocol
    private static final String RESPONSE_CODE = "RESPONSE_CODE";
    private static final String BUY_INTENT = "BUY_INTENT";
    private static final String DETAILS_LIST = "DETAILS_LIST";
    private static final String ITEM_ID_LIST = "ITEM_ID_LIST";
    private static final String INAPP_PURCHASE_DATA = "INAPP_PURCHASE_DATA";
    private static final String INAPP_DATA_SIGNATURE = "INAPP_DATA_SIGNATURE";

    private IInAppBillingService service;
    private ServiceConnection connection;
    private boolean connected = false;
    private String pendingSku = "";

    public GodotMyketBilling(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "GodotMyketBilling";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(new SignalInfo("connection_succeed"));
        signals.add(new SignalInfo("connection_failed", String.class));
        signals.add(new SignalInfo("disconnected"));
        signals.add(new SignalInfo("products_received", String.class));
        signals.add(new SignalInfo("purchase_succeed", String.class, String.class));
        signals.add(new SignalInfo("purchase_failed", String.class, String.class));
        signals.add(new SignalInfo("purchase_canceled", String.class));
        signals.add(new SignalInfo("consume_finished", String.class, Boolean.class));
        return signals;
    }

    // ---------------------------------------------------------------- connection

    @UsedByGodot
    public void openConnection(final String publicKey) {
        Activity activity = getActivity();
        if (activity == null) {
            emitSignal("connection_failed", "no activity");
            return;
        }
        if (connected) {
            emitSignal("connection_succeed");
            return;
        }
        connection = new ServiceConnection() {
            @Override
            public void onServiceConnected(ComponentName name, IBinder binder) {
                service = IInAppBillingService.Stub.asInterface(binder);
                try {
                    int supported = service.isBillingSupported(
                            API_VERSION, getPackageName(), ITEM_TYPE);
                    if (supported == 0) {
                        connected = true;
                        emitSignal("connection_succeed");
                    } else {
                        emitSignal("connection_failed", "billing unsupported: " + supported);
                    }
                } catch (RemoteException e) {
                    emitSignal("connection_failed", String.valueOf(e.getMessage()));
                }
            }

            @Override
            public void onServiceDisconnected(ComponentName name) {
                service = null;
                connected = false;
                emitSignal("disconnected");
            }
        };
        Intent intent = new Intent(BIND_ACTION);
        intent.setPackage(MYKET_PACKAGE);
        try {
            boolean bound = activity.bindService(intent, connection, Context.BIND_AUTO_CREATE);
            if (!bound) {
                emitSignal("connection_failed", "Myket is not installed");
            }
        } catch (SecurityException e) {
            emitSignal("connection_failed", "bind refused: " + e.getMessage());
        }
    }

    @UsedByGodot
    public void closeConnection() {
        Activity activity = getActivity();
        if (activity != null && connection != null) {
            try {
                activity.unbindService(connection);
            } catch (IllegalArgumentException ignored) {
                // already unbound
            }
        }
        connection = null;
        service = null;
        connected = false;
    }

    @UsedByGodot
    public boolean isConnected() {
        return connected;
    }

    // ---------------------------------------------------------------- products

    /** Emits products_received with a JSON array string of {sku,title,description,price}. */
    @UsedByGodot
    public void getProducts(final String[] skus) {
        if (!connected) {
            emitSignal("products_received", "[]");
            return;
        }
        new Thread(() -> {
            try {
                ArrayList<String> ids = new ArrayList<>();
                for (String s : skus) {
                    ids.add(s);
                }
                Bundle query = new Bundle();
                query.putStringArrayList(ITEM_ID_LIST, ids);
                Bundle result = service.getSkuDetails(
                        API_VERSION, getPackageName(), ITEM_TYPE, query);
                StringBuilder json = new StringBuilder("[");
                if (result != null && result.getInt(RESPONSE_CODE) == 0) {
                    ArrayList<String> details = result.getStringArrayList(DETAILS_LIST);
                    if (details != null) {
                        for (int i = 0; i < details.size(); i++) {
                            if (i > 0) {
                                json.append(",");
                            }
                            json.append(details.get(i));
                        }
                    }
                }
                json.append("]");
                emitSignal("products_received", json.toString());
            } catch (Exception e) {
                Log.w(TAG, "getProducts failed", e);
                emitSignal("products_received", "[]");
            }
        }).start();
    }

    // ---------------------------------------------------------------- purchase

    @UsedByGodot
    public void purchase(final String sku, final String payload) {
        Activity activity = getActivity();
        if (!connected || activity == null) {
            emitSignal("purchase_failed", sku, "not connected");
            return;
        }
        pendingSku = sku;
        try {
            Bundle buy = service.getBuyIntent(
                    API_VERSION, getPackageName(), sku, ITEM_TYPE, payload);
            int code = buy.getInt(RESPONSE_CODE);
            if (code != 0) {
                emitSignal("purchase_failed", sku, "response " + code);
                return;
            }
            PendingIntent pending = buy.getParcelable(BUY_INTENT);
            if (pending == null) {
                emitSignal("purchase_failed", sku, "no buy intent");
                return;
            }
            activity.startIntentSenderForResult(pending.getIntentSender(),
                    PURCHASE_REQUEST, new Intent(), 0, 0, 0);
        } catch (RemoteException | IntentSender.SendIntentException e) {
            emitSignal("purchase_failed", sku, String.valueOf(e.getMessage()));
        }
    }

    @Override
    public void onMainActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        if (requestCode != PURCHASE_REQUEST) {
            return;
        }
        String sku = pendingSku;
        pendingSku = "";
        if (data == null) {
            emitSignal("purchase_canceled", sku);
            return;
        }
        int code = data.getIntExtra(RESPONSE_CODE, 0);
        if (resultCode != Activity.RESULT_OK || code != 0) {
            emitSignal("purchase_canceled", sku);
            return;
        }
        String purchaseData = data.getStringExtra(INAPP_PURCHASE_DATA);
        String signature = data.getStringExtra(INAPP_DATA_SIGNATURE);
        if (purchaseData == null) {
            emitSignal("purchase_failed", sku, "empty purchase data");
            return;
        }
        try {
            JSONObject o = new JSONObject(purchaseData);
            String boughtSku = o.optString("productId", sku);
            // The caller consumes with the token; the signature is passed through so a
            // server-side check can be added later without changing this plugin.
            JSONObject out = new JSONObject();
            out.put("productId", boughtSku);
            out.put("purchaseToken", o.optString("purchaseToken"));
            out.put("orderId", o.optString("orderId"));
            out.put("payload", o.optString("developerPayload"));
            out.put("signature", signature == null ? "" : signature);
            emitSignal("purchase_succeed", boughtSku, out.toString());
        } catch (Exception e) {
            emitSignal("purchase_failed", sku, "bad purchase json");
        }
    }

    // ---------------------------------------------------------------- consume

    /** Consumables must be consumed or the SKU stays "owned" and cannot be bought again. */
    @UsedByGodot
    public void consume(final String purchaseToken) {
        if (!connected) {
            emitSignal("consume_finished", purchaseToken, false);
            return;
        }
        new Thread(() -> {
            boolean ok = false;
            try {
                ok = service.consumePurchase(API_VERSION, getPackageName(), purchaseToken) == 0;
            } catch (Exception e) {
                Log.w(TAG, "consume failed", e);
            }
            emitSignal("consume_finished", purchaseToken, ok);
        }).start();
    }

    private String getPackageName() {
        Activity activity = getActivity();
        return activity == null ? "" : activity.getPackageName();
    }
}
