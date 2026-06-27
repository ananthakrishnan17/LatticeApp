package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.AddressRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.service.AddressBookService;
import com.nammananban.ecommerce.service.EcAuthService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/ec/addresses")
public class AddressBookController {
    private final AddressBookService addressBookService;
    private final EcAuthService ecAuthService;

    public AddressBookController(AddressBookService addressBookService, EcAuthService ecAuthService) {
        this.addressBookService = addressBookService;
        this.ecAuthService = ecAuthService;
    }

    @GetMapping
    public List<Map<String, Object>> list() {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return addressBookService.listAddresses(principal);
    }

    @PostMapping
    public Map<String, Object> add(@Valid @RequestBody AddressRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return addressBookService.addAddress(request, principal);
    }

    @PutMapping("/{id}")
    public Map<String, Object> update(@PathVariable UUID id, @Valid @RequestBody AddressRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return addressBookService.updateAddress(id, request, principal);
    }

    @DeleteMapping("/{id}")
    public Map<String, Object> delete(@PathVariable UUID id) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return addressBookService.deleteAddress(id, principal);
    }

    @PostMapping("/{id}/set-default")
    public Map<String, Object> setDefault(@PathVariable UUID id) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return addressBookService.setDefault(id, principal);
    }
}
