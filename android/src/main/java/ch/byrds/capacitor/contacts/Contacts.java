package ch.byrds.capacitor.contacts;

import static android.provider.ContactsContract.Data.MIMETYPE;

import android.Manifest;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.ContactsContract;
import android.provider.ContactsContract.CommonDataKinds.Email;
import android.provider.ContactsContract.CommonDataKinds.Event;
import android.provider.ContactsContract.CommonDataKinds.Organization;
import android.provider.ContactsContract.CommonDataKinds.Phone;
import android.provider.ContactsContract.CommonDataKinds.Photo;
import android.provider.ContactsContract.CommonDataKinds.StructuredName;
import android.provider.ContactsContract.CommonDataKinds.StructuredPostal;
import android.provider.ContactsContract.CommonDataKinds.Website;
import android.util.Base64;
import android.util.Log;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.URL;
import java.net.URLConnection;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.json.JSONException;
import org.json.JSONObject;

@CapacitorPlugin(
        name = "Contacts",
        //requestCodes is labeled as legacy in bridge
        requestCodes = Contacts.REQUEST_CODE,
        permissions = {@Permission(strings = {Manifest.permission.READ_CONTACTS, Manifest.permission.WRITE_CONTACTS}, alias = "contacts")}
)
public class Contacts extends Plugin {

    public static final String LOG_TAG = "Contacts";

    /**
     * Unique request code
     */
    public static final int REQUEST_CODE = 0x1651;

    private static final String CONTACT_ID = "contactId";
    private static final String EMAILS = "emails";
    private static final String EMAIL_LABEL = "label";
    private static final String EMAIL_ADDRESS = "address";
    private static final String PHONE_NUMBERS = "phoneNumbers";
    private static final String PHONE_LABEL = "label";
    private static final String PHONE_NUMBER = "number";
    private static final String DISPLAY_NAME = "displayName";
    private static final String PHOTO_THUMBNAIL = "photoThumbnail";
    private static final String ORGANIZATION_NAME = "organizationName";
    private static final String ORGANIZATION_ROLE = "organizationRole";
    private static final String BIRTHDAY = "birthday";

    @PluginMethod
    public void getPermissions(PluginCall call) {
        if (!hasRequiredPermissions()) {
            requestPermissions(call);
        } else {
            JSObject result = new JSObject();
            result.put("granted", true);
            call.resolve(result);
        }
    }

    @Override
    protected void handleRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.handleRequestPermissionsResult(requestCode, permissions, grantResults);

        PluginCall savedCall = getSavedCall();
        JSObject result = new JSObject();

        if (!hasRequiredPermissions()) {
            result.put("granted", false);
            savedCall.resolve(result);
        } else {
            result.put("granted", true);
            savedCall.resolve(result);
        }
    }

    @PluginMethod
    public void getContacts(PluginCall call) {
        JSArray jsContacts = new JSArray();

        ContentResolver contentResolver = getContext().getContentResolver();

        String[] projection = new String[]{
                MIMETYPE,
                Organization.TITLE,
                ContactsContract.Contacts._ID,
                ContactsContract.Data.CONTACT_ID,
                ContactsContract.Contacts.DISPLAY_NAME,
                ContactsContract.Contacts.Photo.PHOTO,
                ContactsContract.CommonDataKinds.Contactables.DATA,
                ContactsContract.CommonDataKinds.Contactables.TYPE,
                ContactsContract.CommonDataKinds.Contactables.LABEL
        };
        String selection = MIMETYPE + " in (?, ?, ?, ?, ?)";
        String[] selectionArgs = new String[]{
                Email.CONTENT_ITEM_TYPE,
                Phone.CONTENT_ITEM_TYPE,
                Event.CONTENT_ITEM_TYPE,
                Organization.CONTENT_ITEM_TYPE,
                Photo.CONTENT_ITEM_TYPE
        };

        Cursor contactsCursor = contentResolver.query(ContactsContract.Data.CONTENT_URI, projection, selection, selectionArgs, null);

        if (contactsCursor != null && contactsCursor.getCount() > 0) {
            HashMap<Object, JSObject> contactsById = new HashMap<>();

            while (contactsCursor.moveToNext()) {
                String _id = contactsCursor.getString(contactsCursor.getColumnIndex(ContactsContract.Contacts._ID));
                String contactId = contactsCursor.getString(contactsCursor.getColumnIndex(ContactsContract.Data.CONTACT_ID));

                JSObject jsContact = new JSObject();

                if (!contactsById.containsKey(contactId)) {
                    // this contact does not yet exist in HashMap,
                    // so put it to the HashMap

                    jsContact.put(CONTACT_ID, contactId);
                    String displayName = contactsCursor.getString(contactsCursor.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME));

                    jsContact.put(DISPLAY_NAME, displayName);
                    JSArray jsPhoneNumbers = new JSArray();
                    jsContact.put(PHONE_NUMBERS, jsPhoneNumbers);
                    JSArray jsEmailAddresses = new JSArray();
                    jsContact.put(EMAILS, jsEmailAddresses);

                    jsContacts.put(jsContact);
                } else {
                    // this contact already exists,
                    // retrieve it
                    jsContact = contactsById.get(contactId);
                }

                if (jsContact != null) {
                    String mimeType = contactsCursor.getString(contactsCursor.getColumnIndex(MIMETYPE));
                    String data = contactsCursor.getString(
                            contactsCursor.getColumnIndex(ContactsContract.CommonDataKinds.Contactables.DATA)
                    );
                    int type = contactsCursor.getInt(contactsCursor.getColumnIndex(ContactsContract.CommonDataKinds.Contactables.TYPE));
                    String label = contactsCursor.getString(
                            contactsCursor.getColumnIndex(ContactsContract.CommonDataKinds.Contactables.LABEL)
                    );

                    // email
                    switch (mimeType) {
                        case Email.CONTENT_ITEM_TYPE:
                            try {
                                // add this email to the list
                                JSArray emailAddresses = (JSArray) jsContact.get(EMAILS);
                                JSObject jsEmail = new JSObject();
                                jsEmail.put(EMAIL_LABEL, mapEmailTypeToLabel(type, label));
                                jsEmail.put(EMAIL_ADDRESS, data);
                                emailAddresses.put(jsEmail);
                            } catch (JSONException e) {
                                e.printStackTrace();
                            }
                            break;
                        // phone
                        case Phone.CONTENT_ITEM_TYPE:
                            try {
                                // add this phone to the list
                                JSArray jsPhoneNumbers = (JSArray) jsContact.get(PHONE_NUMBERS);
                                JSObject jsPhone = new JSObject();
                                jsPhone.put(PHONE_LABEL, mapPhoneTypeToLabel(type, label));
                                jsPhone.put(PHONE_NUMBER, data);
                                jsPhoneNumbers.put(jsPhone);
                            } catch (JSONException e) {
                                e.printStackTrace();
                            }
                            break;
                        // birthday
                        case Event.CONTENT_ITEM_TYPE:
                            int eventType = contactsCursor.getInt(
                                    contactsCursor.getColumnIndex(ContactsContract.CommonDataKinds.Contactables.TYPE)
                            );
                            if (eventType == Event.TYPE_BIRTHDAY) {
                                jsContact.put(BIRTHDAY, data);
                            }
                            break;
                        // organization
                        case Organization.CONTENT_ITEM_TYPE:
                            jsContact.put(ORGANIZATION_NAME, data);
                            String organizationRole = contactsCursor.getString(contactsCursor.getColumnIndex(Organization.TITLE));
                            if (organizationRole != null) {
                                jsContact.put(ORGANIZATION_ROLE, organizationRole);
                            }
                            break;
                        // photo
                        case Photo.CONTENT_ITEM_TYPE:
                            byte[] thumbnailPhoto = contactsCursor.getBlob(
                                    contactsCursor.getColumnIndex(ContactsContract.Contacts.Photo.PHOTO)
                            );
                            if (thumbnailPhoto != null) {
                                String encodedThumbnailPhoto = Base64.encodeToString(thumbnailPhoto, Base64.NO_WRAP);
                                jsContact.put(PHOTO_THUMBNAIL, "data:image/png;base64," + encodedThumbnailPhoto);
                            }
                            break;
                    }

                    contactsById.put(contactId, jsContact);
                }
            }
        }
        if (contactsCursor != null) {
            contactsCursor.close();
        }

        JSObject result = new JSObject();
        result.put("contacts", jsContacts);
        call.resolve(result);
    }

    @PluginMethod
    public void getGroups(PluginCall call) {
        JSObject result = new JSObject();
        JSArray jsGroups = new JSArray();
        Cursor dataCursor = getContext().getContentResolver().query(ContactsContract.Groups.CONTENT_URI, null, null, null, null);

        while (dataCursor.moveToNext()) {
            JSObject jsGroup = new JSObject();
            String groupId = dataCursor.getString(dataCursor.getColumnIndex(ContactsContract.Groups._ID));
            jsGroup.put("groupId", groupId);
            jsGroup.put("accountType", dataCursor.getString(dataCursor.getColumnIndex(ContactsContract.Groups.ACCOUNT_TYPE)));
            jsGroup.put("accountName", dataCursor.getString(dataCursor.getColumnIndex(ContactsContract.Groups.ACCOUNT_NAME)));
            jsGroup.put("title", dataCursor.getString(dataCursor.getColumnIndex(ContactsContract.Groups.TITLE)));
            jsGroups.put(jsGroup);
        }
        dataCursor.close();

        result.put("groups", jsGroups);
        call.resolve(result);
    }

    @PluginMethod
    public void getContactGroups(PluginCall call) {
        Cursor dataCursor = getContext()
                .getContentResolver()
                .query(
                        ContactsContract.Data.CONTENT_URI,
                        new String[]{ContactsContract.Data.CONTACT_ID, ContactsContract.Data.DATA1},
                        MIMETYPE + "=?",
                        new String[]{ContactsContract.CommonDataKinds.GroupMembership.CONTENT_ITEM_TYPE},
                        null
                );

        Map<String, Set<String>> contact2GroupMap = new HashMap<>();
        while (dataCursor.moveToNext()) {
            String contact_id = dataCursor.getString(0);
            String group_id = dataCursor.getString(1);

            Set<String> groups = new HashSet<>();
            if (contact2GroupMap.containsKey(contact_id)) {
                groups = contact2GroupMap.get(contact_id);
            }
            groups.add(group_id);
            contact2GroupMap.put(contact_id, groups);
        }
        dataCursor.close();

        JSObject result = new JSObject();
        for (Map.Entry<String, Set<String>> entry : contact2GroupMap.entrySet()) {
            JSArray jsGroups = new JSArray();
            Set<String> groups = entry.getValue();
            for (String group : groups) {
                jsGroups.put(group);
            }
            result.put(entry.getKey(), jsGroups);
        }

        call.resolve(result);
    }

    @PluginMethod
    public void deleteContact(PluginCall call) {
        Uri uri = Uri.withAppendedPath(ContactsContract.Contacts.CONTENT_LOOKUP_URI, call.getString(CONTACT_ID));
        getContext().getContentResolver().delete(uri, null, null);

        JSObject result = new JSObject();
        call.resolve(result);
    }

    @PluginMethod
    public void saveContact(PluginCall call) throws JSONException {

        // Use "Data" interface to insert data into the ContactsContract.Data table
        ArrayList<ContentValues> data = new ArrayList<ContentValues>();

        // name
        ContentValues name = new ContentValues();
        name.put(MIMETYPE, StructuredName.CONTENT_ITEM_TYPE);
        name.put(StructuredName.PREFIX, call.getString("namePrefix", ""));
        name.put(StructuredName.GIVEN_NAME, call.getString("givenName", ""));
        name.put(StructuredName.MIDDLE_NAME, call.getString("middleName", ""));
        name.put(StructuredName.FAMILY_NAME, call.getString("familyName", ""));
        name.put(StructuredName.SUFFIX, call.getString("nameSuffix", ""));
        data.add(name);

        ContentValues organisation = new ContentValues();
        organisation.put(MIMETYPE, Organization.CONTENT_ITEM_TYPE);
        organisation.put(Organization.COMPANY, call.getString("organizationName", ""));
        organisation.put(Organization.TITLE, call.getString("jobTitle", ""));
        data.add(organisation);

        // email addresses
        JSArray emailAddressesArray = call.getArray("emailAddresses", new JSArray());
        List<Object> emailAddresses = emailAddressesArray.toList();
        for (int i = 0; i < emailAddresses.size(); i++) {
            JSObject emailAddress = JSObject.fromJSONObject((JSONObject) emailAddresses.get(i));
            ContentValues email = new ContentValues();
            email.put(MIMETYPE, Email.CONTENT_ITEM_TYPE);
            email.put(Email.TYPE, Email.TYPE_CUSTOM);
            email.put(Email.LABEL, emailAddress.getString("label", ""));
            email.put(Email.ADDRESS, emailAddress.getString("address", ""));
            data.add(email);
        }

        // phone numbers
        JSArray phoneNumbersArray = call.getArray("phoneNumbers", new JSArray());
        List<Object> phoneNumbers = phoneNumbersArray.toList();
        for (int i = 0; i < phoneNumbers.size(); i++) {
            JSObject phoneNumber = JSObject.fromJSONObject((JSONObject) phoneNumbers.get(i));
            ContentValues phone = new ContentValues();
            phone.put(MIMETYPE, Phone.CONTENT_ITEM_TYPE);
            phone.put(Phone.TYPE, Phone.TYPE_CUSTOM);
            phone.put(Phone.LABEL, phoneNumber.getString("label", ""));
            phone.put(Phone.NUMBER, phoneNumber.getString("number", ""));
            data.add(phone);
        }

        // url addresses
        JSArray urlAddressesArray = call.getArray("urlAddresses", new JSArray());
        List<Object> urlAddresses = urlAddressesArray.toList();
        for (int i = 0; i < urlAddresses.size(); i++) {
            JSObject urlAddress = JSObject.fromJSONObject((JSONObject) urlAddresses.get(i));
            ContentValues url = new ContentValues();
            url.put(MIMETYPE, Website.CONTENT_ITEM_TYPE);
            url.put(Website.TYPE, Website.TYPE_CUSTOM);
            url.put(Website.LABEL, urlAddress.getString("label", ""));
            url.put(Website.URL, urlAddress.getString("url", ""));
            data.add(url);
        }

        // postal addresses
        JSArray postalAddressesArray = call.getArray("postalAddresses", new JSArray());
        List<Object> postalAddresses = postalAddressesArray.toList();
        for (int i = 0; i < postalAddresses.size(); i++) {
            JSObject postalAddress = JSObject.fromJSONObject((JSONObject) postalAddresses.get(i));
            ContentValues postal = new ContentValues();
            postal.put(MIMETYPE, StructuredPostal.CONTENT_ITEM_TYPE);
            postal.put(StructuredPostal.TYPE, StructuredPostal.TYPE_CUSTOM);
            postal.put(StructuredPostal.LABEL, postalAddress.getString("label", ""));
            postal.put(StructuredPostal.STREET, postalAddress.getString("street", ""));
            postal.put(StructuredPostal.POSTCODE, postalAddress.getString("postalCode", ""));
            postal.put(StructuredPostal.CITY, postalAddress.getString("city", ""));
            postal.put(StructuredPostal.REGION, postalAddress.getString("state", ""));
            postal.put(StructuredPostal.COUNTRY, postalAddress.getString("country", ""));
            data.add(postal);
        }

        // social profiles
        JSArray socialProfilesArray = call.getArray("socialProfiles", new JSArray());
        List<Object> socialProfiles = socialProfilesArray.toList();
        for (int i = 0; i < socialProfiles.size(); i++) {
            JSObject socialProfile = JSObject.fromJSONObject((JSONObject) socialProfiles.get(i));
            ContentValues url = new ContentValues();
            url.put(MIMETYPE, Website.CONTENT_ITEM_TYPE);
            url.put(Website.TYPE, Website.TYPE_CUSTOM);
            JSObject profile = socialProfile.getJSObject("profile");
            if (profile != null) {
                url.put(Website.LABEL, profile.getString("service", ""));
                url.put(Website.URL, profile.getString("urlString", ""));
                data.add(url);
            }
        }

        // image
        String image = call.getString("image", "");
        if (image != null && !image.isEmpty()) {
            ContentValues photo = new ContentValues();
            photo.put(MIMETYPE, Photo.CONTENT_ITEM_TYPE);

            photo.put(Photo.PHOTO, this.getBytesFromUrl(image));

            data.add(photo);
        }




        String identifier = call.getString("identifier", "");

        Intent intent;

        if(identifier.isEmpty()) {
            intent = new Intent(Intent.ACTION_INSERT, ContactsContract.Contacts.CONTENT_URI);
        } else {

            long idContact = Long.parseLong(identifier);

            // update contact
            intent = new Intent(Intent.ACTION_EDIT);
            Uri contactUri = ContentUris.withAppendedId(ContactsContract.Contacts.CONTENT_URI, idContact);
            intent.setData(contactUri);
        }

        intent.putParcelableArrayListExtra(ContactsContract.Intents.Insert.DATA, data);

        // --- Save


        getContext().startActivity(intent);

        Log.w("", intent.toString());

        call.resolve();
    }

    private String mapPhoneTypeToLabel(int type, String defaultLabel) {
        switch (type) {
            case Phone.TYPE_MOBILE:
                return "mobile";
            case Phone.TYPE_HOME:
                return "home";
            case Phone.TYPE_WORK:
                return "work";
            case Phone.TYPE_FAX_WORK:
                return "fax work";
            case Phone.TYPE_FAX_HOME:
                return "fax home";
            case Phone.TYPE_PAGER:
                return "pager";
            case Phone.TYPE_OTHER:
                return "other";
            case Phone.TYPE_CALLBACK:
                return "callback";
            case Phone.TYPE_CAR:
                return "car";
            case Phone.TYPE_COMPANY_MAIN:
                return "company main";
            case Phone.TYPE_ISDN:
                return "isdn";
            case Phone.TYPE_MAIN:
                return "main";
            case Phone.TYPE_OTHER_FAX:
                return "other fax";
            case Phone.TYPE_RADIO:
                return "radio";
            case Phone.TYPE_TELEX:
                return "telex";
            case Phone.TYPE_TTY_TDD:
                return "tty";
            case Phone.TYPE_WORK_MOBILE:
                return "work mobile";
            case Phone.TYPE_WORK_PAGER:
                return "work pager";
            case Phone.TYPE_ASSISTANT:
                return "assistant";
            case Phone.TYPE_MMS:
                return "mms";
            default:
                return defaultLabel;
        }
    }

    private String mapEmailTypeToLabel(int type, String defaultLabel) {
        switch (type) {
            case Email.TYPE_HOME:
                return "home";
            case Email.TYPE_WORK:
                return "work";
            case Email.TYPE_OTHER:
                return "other";
            case Email.TYPE_MOBILE:
                return "mobile";
            default:
                return defaultLabel;
        }
    }

    private byte[] getBytesFromUrl(String url) {

        try {
            URL imageUrl = new URL(url);
            URLConnection ucon = imageUrl.openConnection();
            InputStream is = ucon.getInputStream();
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            byte[] buffer = new byte[1024];
            int read = 0;
            while ((read = is.read(buffer, 0, buffer.length)) != -1) {
                baos.write(buffer, 0, read);
            }
            baos.flush();
            return baos.toByteArray();
//      return "data:image/png;base64," + Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP);
        } catch (Exception e) {
            Log.d("Error", e.toString());
        }
        return null;
    }
}
